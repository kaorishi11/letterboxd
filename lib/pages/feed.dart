import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../componets/navbar.dart';

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

      // Carregar curtidas para cada avaliação
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
      // Contar curtidas
      final countResponse = await supabase
          .from('curtidas')
          .select('id')
          .eq('avaliacao_id', reviewId);

      setState(() {
        likesCount[reviewId] = countResponse.length;
      });

      // Verificar se usuário atual curtiu
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

    // Atualizar UI imediatamente
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
      // Reverter em caso de erro
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
      appBar: AppBar(
        title: const Text(
          'CineFeed',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notificações em breve')),
              );
            },
            tooltip: 'Notificações',
          ),
          IconButton(
            icon: const Icon(Icons.rate_review_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Adicionar avaliação em breve')),
              );
            },
            tooltip: 'Adicionar Avaliação',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadData,
              child: CustomScrollView(
                slivers: [
                  // Destaques da Semana
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Destaques da Semana',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (highlights.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('Nenhum filme em destaque no momento'),
                            ),
                          )
                        else
                          SizedBox(
                            height: 240,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: highlights.length,
                              itemBuilder: (context, index) {
                                final movie = highlights[index];
                                return Container(
                                  width: 140,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          movie['poster_url'] ?? '',
                                          height: 180,
                                          width: 140,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              height: 180,
                                              width: 140,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.movie,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        movie['titulo'] ?? 'Sem título',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        const Divider(height: 32),
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
                                    SizedBox(height: 8),
                                    Text(
                                      'Seja o primeiro a avaliar um filme!',
                                      style: TextStyle(fontSize: 14, color: Colors.grey),
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
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                                              radius: 20,
                                              backgroundImage: user?['foto_perfil'] != null && user!['foto_perfil']!.isNotEmpty
                                                  ? NetworkImage(user['foto_perfil']!)
                                                  : null,
                                              child: (user?['foto_perfil'] == null || user!['foto_perfil']!.isEmpty)
                                                  ? Text(
                                                      (user?['nome'] ?? 'U')[0].toUpperCase(),
                                                      style: const TextStyle(fontSize: 16),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user?['nome'] ?? 'Usuário',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatDate(review['created_at']),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // Info do Filme
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                movie?['poster_url'] ?? '',
                                                height: 80,
                                                width: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    height: 80,
                                                    width: 60,
                                                    color: Colors.grey[300],
                                                    child: const Icon(Icons.movie, color: Colors.grey),
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
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      ...List.generate(5, (starIndex) {
                                                        return Icon(
                                                          starIndex < (review['nota'] ?? 0)
                                                              ? Icons.star
                                                              : Icons.star_border,
                                                          color: Colors.amber,
                                                          size: 20,
                                                        );
                                                      }),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '(${review['nota']}/5)',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
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
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              review['comentario'],
                                              style: const TextStyle(fontSize: 14, height: 1.4),
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                        
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
                                                          ? Colors.red
                                                          : Colors.grey,
                                                      size: 24,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${likesCount[reviewId] ?? 0}',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
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
                                                      Icons.comment_outlined,
                                                      size: 22,
                                                      color: Colors.grey[700],
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Comentar',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
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
                ],
              ),
            ),
      bottomNavigationBar: CustomNavbar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Já está no Feed
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
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
}