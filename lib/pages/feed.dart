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
  List<Map<String, dynamic>> filteredReviews = [];
  Map<String, bool> likedStatus = {};
  Map<String, int> likesCount = {};
  Map<String, List<Map<String, dynamic>>> comments = {};
  Map<String, bool> showComments = {};
  bool isLoading = true;
  
  // Controle da busca
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // Cores da paleta
  final Color backgroundColor = const Color(0xFFF3EEC8);
  final Color primaryColor = const Color(0xFF473835);
  final Color accentColor = const Color(0xFFB85C5A);

  @override
  void initState() {
    super.initState();
    loadData();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = searchController.text;
      _filterReviews();
    });
  }

  void _filterReviews() {
    if (searchQuery.isEmpty) {
      filteredReviews = List.from(reviews);
    } else {
      filteredReviews = reviews.where((review) {
        final user = review['usuarios'];
        final movie = review['filmes'];
        final userName = user?['nome']?.toString().toLowerCase() ?? '';
        final movieTitle = movie?['titulo']?.toString().toLowerCase() ?? '';
        final comment = review['comentario']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        
        return userName.contains(query) || 
               movieTitle.contains(query) || 
               comment.contains(query);
      }).toList();
    }
    setState(() {});
  }

  void _toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        searchController.clear();
        searchQuery = '';
        _filterReviews();
      }
    });
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
        filteredReviews = List.from(reviews);
      });

      // Inicializar mapas para cada review
      for (var review in reviews) {
        final reviewId = review['id'].toString();
        comments[reviewId] = [];
        showComments[reviewId] = false;
        likedStatus[reviewId] = false;
        likesCount[reviewId] = 0;
      }

      // Carregar dados para cada review
      for (var review in reviews) {
        final reviewId = review['id'].toString();
        await Future.wait([
          loadLikesForReview(reviewId),
          loadCommentsForReview(reviewId),
        ]);
      }
    } catch (e) {
      debugPrint('Erro ao carregar avaliações: $e');
      setState(() {
        reviews = [];
        filteredReviews = [];
      });
    }
  }

  Future<void> loadLikesForReview(String reviewId) async {
    try {
      final countResponse = await supabase
          .from('curtidas')
          .select('id')
          .eq('avaliacao_id', reviewId);

      if (mounted) {
        setState(() {
          likesCount[reviewId] = countResponse.length;
        });
      }

      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        final likeResponse = await supabase
            .from('curtidas')
            .select('id')
            .eq('avaliacao_id', reviewId)
            .eq('usuario_id', currentUser.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            likedStatus[reviewId] = likeResponse != null;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar curtidas: $e');
    }
  }

  Future<void> loadCommentsForReview(String reviewId) async {
    try {
      final response = await supabase
          .from('comentarios')
          .select('''
            *,
            usuarios (id, nome, foto_perfil)
          ''')
          .eq('avaliacao_id', reviewId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          comments[reviewId] = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar comentários: $e');
      if (mounted) {
        setState(() {
          comments[reviewId] = [];
        });
      }
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
    final currentCount = likesCount[reviewId] ?? 0;

    setState(() {
      likedStatus[reviewId] = !isLiked;
      likesCount[reviewId] = currentCount + (isLiked ? -1 : 1);
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
      if (mounted) {
        setState(() {
          likedStatus[reviewId] = isLiked;
          likesCount[reviewId] = currentCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao curtir avaliação')),
        );
      }
    }
  }

  Future<void> addComment(String reviewId, String commentText) async {
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para comentar')),
      );
      return;
    }

    if (commentText.trim().isEmpty) return;

    try {
      final response = await supabase.from('comentarios').insert({
        'avaliacao_id': reviewId,
        'usuario_id': currentUser.id,
        'comentario': commentText,
      }).select('''
        *,
        usuarios (id, nome, foto_perfil)
      ''');

      if (mounted && response.isNotEmpty) {
        setState(() {
          comments[reviewId]?.insert(0, response[0] as Map<String, dynamic>);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comentário adicionado!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar comentário: $e')),
        );
      }
    }
  }

  Future<void> deleteComment(String reviewId, String commentId) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await supabase
          .from('comentarios')
          .delete()
          .eq('id', commentId);

      if (mounted) {
        setState(() {
          comments[reviewId]?.removeWhere((c) => c['id'].toString() == commentId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comentário removido!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover comentário: $e')),
        );
      }
    }
  }

  void _showCommentDialog(String reviewId) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adicionar comentário',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'O que você achou dessa avaliação?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (commentController.text.trim().isNotEmpty) {
                          addComment(reviewId, commentController.text);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: backgroundColor,
                      ),
                      child: const Text('Comentar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSearching ? 120 : 80),
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
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
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EEC8).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isSearching ? Icons.close : Icons.search,
                                color: const Color(0xFFF3EEC8),
                                size: 22,
                              ),
                              onPressed: _toggleSearch,
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
                // Barra de busca expansível
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: isSearching ? 56 : 0,
                  child: isSearching
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3EEC8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: searchController,
                              autofocus: true,
                              style: const TextStyle(color: Color(0xFFF3EEC8)),
                              decoration: InputDecoration(
                                hintText: 'Buscar por usuário, filme ou comentário...',
                                hintStyle: TextStyle(color: const Color(0xFFF3EEC8).withValues(alpha: 0.5)),
                                prefixIcon: Icon(Icons.search, color: const Color(0xFFF3EEC8).withValues(alpha: 0.5)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
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
                  
                  // Resultado da busca
                  if (isSearching && searchQuery.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Resultados para: "$searchQuery" (${filteredReviews.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: primaryColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: filteredReviews.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: isSearching ? 32 : 0,
                                bottom: 32,
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      isSearching ? Icons.search_off : Icons.rate_review,
                                      size: 64,
                                      color: primaryColor.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      isSearching 
                                          ? 'Nenhum resultado encontrado' 
                                          : 'Nenhuma avaliação ainda',
                                      style: TextStyle(
                                        fontSize: 16, 
                                        color: primaryColor.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    if (!isSearching) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Seja o primeiro a avaliar um filme!',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: primaryColor.withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final review = filteredReviews[index];
                                final reviewId = review['id'].toString();
                                final user = review['usuarios'];
                                final movie = review['filmes'];
                                
                                // Garantir que os valores não sejam null
                                final commentList = comments[reviewId] ?? [];
                                final showComment = showComments[reviewId] ?? false;
                                final likeCount = likesCount[reviewId] ?? 0;
                                final isLiked = likedStatus[reviewId] ?? false;
                                
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
                                        // Destaque se for resultado de busca
                                        if (isSearching && searchQuery.isNotEmpty && 
                                            (user?['nome']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false))
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: accentColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.person, size: 12, color: accentColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Corresponde ao usuário',
                                                  style: TextStyle(fontSize: 10, color: accentColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        
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
                                        
                                        // Comentário da avaliação
                                        if (review['comentario'] != null && review['comentario'].toString().isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: backgroundColor.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: _highlightText(
                                              review['comentario'].toString(),
                                              searchQuery,
                                              primaryColor,
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                        
                                        // Botões de Interação
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () => toggleLike(reviewId),
                                              borderRadius: BorderRadius.circular(20),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      isLiked
                                                          ? Icons.favorite
                                                          : Icons.favorite_border,
                                                      color: isLiked
                                                          ? accentColor
                                                          : primaryColor.withValues(alpha: 0.5),
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      likeCount.toString(),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: primaryColor.withValues(alpha: 0.7),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            
                                            // Botão Comentar
                                            InkWell(
                                              onTap: () => _showCommentDialog(reviewId),
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
                                                      commentList.length.toString(),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: primaryColor.withValues(alpha: 0.7),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            
                                            // Botão mostrar/esconder comentários
                                            if (commentList.isNotEmpty)
                                              TextButton(
                                                onPressed: () {
                                                  setState(() {
                                                    showComments[reviewId] = !showComment;
                                                  });
                                                },
                                                child: Text(
                                                  showComment ? 'OCULTAR' : 'VER COMENTÁRIOS',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: primaryColor.withValues(alpha: 0.5),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        
                                        // Lista de comentários
                                        if (showComment && commentList.isNotEmpty)
                                          Column(
                                            children: [
                                              const SizedBox(height: 12),
                                              ...commentList.map((comment) {
                                                final commentUser = comment['usuarios'];
                                                final isOwner = commentUser?['id'] == supabase.auth.currentUser?.id;
                                                
                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: backgroundColor.withValues(alpha: 0.3),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 12,
                                                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                                                        child: Text(
                                                          (commentUser?['nome'] ?? 'U')[0].toUpperCase(),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: primaryColor,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Text(
                                                                  commentUser?['nome'] ?? 'Usuário',
                                                                  style: TextStyle(
                                                                    fontWeight: FontWeight.w600,
                                                                    fontSize: 12,
                                                                    color: primaryColor,
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                Text(
                                                                  _formatDate(comment['created_at']),
                                                                  style: TextStyle(
                                                                    fontSize: 9,
                                                                    color: primaryColor.withValues(alpha: 0.4),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              comment['comentario'],
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: primaryColor.withValues(alpha: 0.8),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (isOwner)
                                                        IconButton(
                                                          icon: Icon(Icons.close, size: 16, color: primaryColor.withValues(alpha: 0.4)),
                                                          onPressed: () => deleteComment(reviewId, comment['id'].toString()),
                                                        ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: filteredReviews.length,
                            ),
                          ),
                  ),
                  
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

  // Widget para destacar texto nos resultados da busca
  Widget _highlightText(String text, String query, Color color) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: primaryColor,
        ),
      );
    }

    final List<TextSpan> spans = [];
    String remaining = text;
    String lowerRemaining = text.toLowerCase();
    String lowerQuery = query.toLowerCase();
    int lastIndex = 0;

    while (true) {
      final index = lowerRemaining.indexOf(lowerQuery, lastIndex);
      if (index == -1) {
        spans.add(TextSpan(text: remaining.substring(lastIndex)));
        break;
      }
      
      if (index > lastIndex) {
        spans.add(TextSpan(text: remaining.substring(lastIndex, index)));
      }
      
      spans.add(
        TextSpan(
          text: remaining.substring(index, index + query.length),
          style: TextStyle(
            backgroundColor: accentColor.withValues(alpha: 0.3),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      
      lastIndex = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: primaryColor,
        ),
        children: spans,
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