import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../componets/navbar.dart';
import 'discover.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> highlights = [];
  List<Map<String, dynamic>> reviews = [];
  Map<String, bool> likedStatus = {};
  Map<String, int> likesCount = {};
  bool isLoading = true;

  // Cores da paleta
  final Color backgroundColor = const Color(0xFFF3EEC8); // #f3eec8
  final Color primaryColor = const Color(0xFF473835); // #473835
  final Color accentColor = const Color(0xFFB85C5A); // Tom complementar

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
    });

    await Future.wait([
      loadHighlights(),
      loadReviews(),
    ]);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> loadHighlights() async {
    try {
      final response = await supabase
          .from('filmes')
          .select('id, titulo, poster_url')
          .eq('destaque_semana', true)
          .limit(10);

      setState(() {
        highlights = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Erro ao carregar destaques: $e');
      setState(() {
        highlights = [];
      });
    }
  }

  Future<void> loadReviews() async {
    try {
      final response = await supabase
          .from('avaliacoes')
          .select('''
            id,
            comentario,
            nota,
            created_at,
            usuarios (id, nome, foto_perfil),
            filmes (id, titulo, poster_url)
          ''')
          .order('created_at', ascending: false);

      setState(() {
        reviews = List<Map<String, dynamic>>.from(response);
      });

      for (var review in reviews) {
        await loadLikesForReview(review['id'].toString());
      }
    } catch (e) {
      debugPrint('Erro ao carregar avaliações: $e');
      setState(() {
        reviews = [];
      });
    }
  }

  Future<void> loadLikesForReview(String reviewId) async {
    try {
      final countResponse = await supabase
          .from('curtidas')
          .select('id')
          .eq('avaliacao_id', reviewId);

      setState(() {
        likesCount[reviewId] = countResponse.length;
      });

      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        final likeResponse = await supabase
            .from('curtidas')
            .select('id')
            .eq('avaliacao_id', reviewId)
            .eq('usuario_id', currentUser.id)
            .maybeSingle();

        setState(() {
          likedStatus[reviewId] = likeResponse != null;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar curtidas: $e');
    }
  }

  Future<void> toggleLike(String reviewId) async {
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para curtir avaliações')),
      );
      return;
    }

    final isLiked = likedStatus[reviewId] ?? false;

    setState(() {
      likedStatus[reviewId] = !isLiked;
      likesCount[reviewId] = (likesCount[reviewId] ?? 0) + (isLiked ? -1 : 1);
    });

    try {
      if (isLiked) {
        await supabase
            .from('curtidas')
            .delete()
            .eq('avaliacao_id', reviewId)
            .eq('usuario_id', currentUser.id);
      } else {
        await supabase.from('curtidas').insert({
          'avaliacao_id': reviewId,
          'usuario_id': currentUser.id,
        });
      }
    } catch (e) {
      setState(() {
        likedStatus[reviewId] = isLiked;
        likesCount[reviewId] = (likesCount[reviewId] ?? 0) + (isLiked ? 1 : -1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao curtir avaliação')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            color: primaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Logo Letterboxd estilizada
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'LETTERBOX',
                        style: TextStyle(
                          color: Color(0xFFF3EEC8),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'DESDE',
                            style: TextStyle(
                              color: Color(0xFFF3EEC8),
                              fontSize: 8,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3EEC8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '2026',
                              style: TextStyle(
                                color: Color(0xFF473835),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Ícones de ação
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEC8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search, color: Color(0xFFF3EEC8), size: 22),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Busca em breve')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_box_outlined, color: Color(0xFFF3EEC8), size: 22),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Adicionar avaliação em breve')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.favorite_border, color: Color(0xFFF3EEC8), size: 22),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Atividades em breve')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadData,
              color: primaryColor,
              child: CustomScrollView(
                slivers: [
                  // Destaques da Semana
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DESTAQUES DA SEMANA',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  letterSpacing: 1,
                                ),
                              ),
                              TextButton(
                                 onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiscoverScreen()),
    );
  },
                                child: Text(
                                  'VER TODOS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primaryColor.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (highlights.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('Nenhum filme em destaque no momento'),
                            ),
                          )
                        else
                          SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: highlights.length,
                              itemBuilder: (context, index) {
                                final movie = highlights[index];
                                return Container(
                                  width: 130,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              movie['poster_url'] ?? '',
                                              height: 170,
                                              width: 130,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  height: 170,
                                                  width: 130,
                                                  color: primaryColor.withValues(alpha: 0.1),
                                                  child: Icon(
                                                    Icons.movie,
                                                    size: 40,
                                                    color: primaryColor.withValues(alpha: 0.3),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          // Nota do filme
                                          Positioned(
                                            bottom: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: primaryColor,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    size: 10,
                                                    color: Color(0xFFF3EEC8),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '4.2',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: backgroundColor,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        movie['titulo'] ?? 'Sem título',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: primaryColor,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        const Divider(height: 32, thickness: 1),
                      ],
                    ),
                  ),
                  
                  // Feed de Avaliações
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: reviews.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.rate_review, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'Nenhuma avaliação ainda',
                                      style: TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final review = reviews[index];
                                final reviewId = review['id'].toString();
                                final user = review['usuarios'];
                                final movie = review['filmes'];
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header do Usuário
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: primaryColor.withValues(alpha: 0.1),
                                              backgroundImage: user?['foto_perfil'] != null && user!['foto_perfil']!.isNotEmpty
                                                  ? NetworkImage(user['foto_perfil']!)
                                                  : null,
                                              child: (user?['foto_perfil'] == null || user!['foto_perfil']!.isEmpty)
                                                  ? Text(
                                                      (user?['nome'] ?? 'U')[0].toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: primaryColor,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user?['nome'] ?? 'Usuário',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatDate(review['created_at']),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: primaryColor.withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Ícone de mais opções
                                            IconButton(
                                              icon: Icon(Icons.more_horiz, size: 18, color: primaryColor.withValues(alpha: 0.5)),
                                              onPressed: () {},
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // Info do Filme
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.network(
                                                movie?['poster_url'] ?? '',
                                                height: 90,
                                                width: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    height: 90,
                                                    width: 60,
                                                    color: primaryColor.withValues(alpha: 0.1),
                                                    child: Icon(
                                                      Icons.movie,
                                                      color: primaryColor.withValues(alpha: 0.3),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    movie?['titulo'] ?? 'Filme',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      ...List.generate(5, (starIndex) {
                                                        return Icon(
                                                          starIndex < (review['nota'] ?? 0)
                                                              ? Icons.star
                                                              : Icons.star_border,
                                                          color: Colors.amber,
                                                          size: 16,
                                                        );
                                                      }),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${(review['nota'] ?? 0).toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: primaryColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Avaliado em ${_formatDetailedDate(review['created_at'])}',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: primaryColor.withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // Comentário
                                        if (review['comentario'] != null && review['comentario'].toString().isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: backgroundColor.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              review['comentario'],
                                              style: TextStyle(
                                                fontSize: 13,
                                                height: 1.4,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                        
                                        // Botões de Interação
                                        Row(
                                          children: [
                                            // Botão Curtir
                                            InkWell(
                                              onTap: () => toggleLike(reviewId),
                                              borderRadius: BorderRadius.circular(20),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      likedStatus[reviewId] == true
                                                          ? Icons.favorite
                                                          : Icons.favorite_border,
                                                      color: likedStatus[reviewId] == true
                                                          ? accentColor
                                                          : primaryColor.withValues(alpha: 0.5),
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${likesCount[reviewId] ?? 0} curtidas',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: primaryColor.withValues(alpha: 0.7),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            
                                            // Botão Comentar
                                            InkWell(
                                              onTap: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(20),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.chat_bubble_outline,
                                                      size: 18,
                                                      color: primaryColor.withValues(alpha: 0.5),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Comentar',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: primaryColor.withValues(alpha: 0.7),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            
                                            // Ícone de compartilhar
                                            IconButton(
                                              icon: Icon(
                                                Icons.share_outlined,
                                                size: 18,
                                                color: primaryColor.withValues(alpha: 0.5),
                                              ),
                                              onPressed: () {},
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: reviews.length,
                            ),
                          ),
                  ),
                  
                  // Footer
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'LETTERBOX',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: primaryColor.withValues(alpha: 0.3),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'DESDE 2026',
                              style: TextStyle(
                                fontSize: 8,
                                letterSpacing: 1,
                                color: primaryColor.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: CustomNavbar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/discover');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Data desconhecida';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return 'há ${difference.inDays} dia${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'há ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return 'há ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'agora mesmo';
      }
    } catch (e) {
      return 'Data desconhecida';
    }
  }

  String _formatDetailedDate(String? dateString) {
    if (dateString == null) return 'data desconhecida';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'data desconhecida';
    }
  }
}