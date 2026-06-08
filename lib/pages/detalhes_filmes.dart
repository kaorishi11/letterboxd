// lib/pages/movie_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MovieDetailScreen extends StatefulWidget {
  final String movieId;
  const MovieDetailScreen({super.key, required this.movieId});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? movie;
  List<Map<String, dynamic>> reviews = [];
  double averageRating = 0;
  bool isLoading = true;
  bool isUserRated = false;
  int? userRating;
  String? userComment;

  final Color backgroundColor = const Color(0xFFF3EEC8);
  final Color primaryColor = const Color(0xFF473835);
  final Color accentColor = const Color(0xFFB85C5A);

  @override
  void initState() {
    super.initState();
    loadMovieData();
  }

  Future<void> loadMovieData() async {
    setState(() {
      isLoading = true;
    });

    await Future.wait([
      loadMovie(),
      loadReviews(),
      loadUserRating(),
    ]);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> loadMovie() async {
    try {
      final response = await supabase
          .from('filmes')
          .select()
          .eq('id', widget.movieId)
          .single();

      setState(() {
        movie = response;
      });
    } catch (e) {
      debugPrint('Erro ao carregar filme: $e');
    }
  }

  Future<void> loadReviews() async {
    try {
      final response = await supabase
          .from('avaliacoes')
          .select('''
            *,
            usuarios (id, nome, foto_perfil)
          ''')
          .eq('filme_id', widget.movieId)
          .order('created_at', ascending: false);

      setState(() {
        reviews = List<Map<String, dynamic>>.from(response);
        
        if (reviews.isNotEmpty) {
          double sum = 0;
          for (var review in reviews) {
            sum += (review['nota'] ?? 0);
          }
          averageRating = sum / reviews.length;
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar avaliações: $e');
    }
  }

  Future<void> loadUserRating() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final response = await supabase
          .from('avaliacoes')
          .select()
          .eq('filme_id', widget.movieId)
          .eq('usuario_id', currentUser.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          isUserRated = true;
          userRating = response['nota'];
          userComment = response['comentario'];
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar avaliação do usuário: $e');
    }
  }

  Future<void> submitRating(int rating, {String? comment}) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para avaliar filmes')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (isUserRated) {
        // Atualizar avaliação existente
        await supabase
            .from('avaliacoes')
            .update({
              'nota': rating,
              'comentario': comment,
            })
            .eq('filme_id', widget.movieId)
            .eq('usuario_id', currentUser.id);
      } else {
        // Criar nova avaliação
        await supabase.from('avaliacoes').insert({
          'usuario_id': currentUser.id,
          'filme_id': widget.movieId,
          'nota': rating,
          'comentario': comment,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação salva com sucesso!')),
      );
      
      await loadReviews();
      await loadUserRating();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar avaliação: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showRatingDialog() {
    int selectedRating = userRating ?? 0;
    TextEditingController commentController = TextEditingController(text: userComment ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUserRated ? 'Editar avaliação' : 'Avaliar filme',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      movie?['titulo'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Sua nota',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setStateSheet(() {
                              selectedRating = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              index < selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Seu comentário (opcional)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'O que você achou do filme?',
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
                              if (selectedRating == 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Selecione uma nota')),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              submitRating(selectedRating, comment: commentController.text);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: backgroundColor,
                            ),
                            child: const Text('Salvar'),
                          ),
                        ),
                      ],
                    ),
                    if (isUserRated)
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _deleteRating();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Excluir avaliação'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRating() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      await supabase
          .from('avaliacoes')
          .delete()
          .eq('filme_id', widget.movieId)
          .eq('usuario_id', currentUser.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação excluída!')),
      );
      
      await loadReviews();
      await loadUserRating();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir avaliação: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : CustomScrollView(
              slivers: [
                // App Bar com poster
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: primaryColor,
                  foregroundColor: backgroundColor,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          movie?['poster_url'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: primaryColor,
                              child: const Icon(
                                Icons.movie,
                                size: 80,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                backgroundColor,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {
                        // Compartilhar filme
                      },
                    ),
                  ],
                ),
                
                // Conteúdo
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título e informações
                        Text(
                          movie?['titulo'] ?? '',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                movie?['ano']?.toString() ?? '',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                movie?['genero'] ?? '',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Média de avaliações
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Média geral',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          index < averageRating.round()
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 20,
                                        );
                                      }),
                                    ),
                                    Text(
                                      '${reviews.length} avaliações',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: primaryColor.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Sinopse
                        const Text(
                          'SINOPSE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          movie?['descricao'] ?? 'Sem descrição disponível',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: primaryColor.withValues(alpha: 0.8),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Botão de avaliar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showRatingDialog,
                            icon: Icon(
                              isUserRated ? Icons.edit : Icons.rate_review,
                            ),
                            label: Text(
                              isUserRated ? 'Editar minha avaliação' : 'Avaliar este filme',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: backgroundColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Avaliações dos usuários
                        const Text(
                          'AVALIAÇÕES',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        if (reviews.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.rate_review_outlined,
                                    size: 64,
                                    color: primaryColor.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Seja o primeiro a avaliar este filme!',
                                    style: TextStyle(
                                      color: primaryColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reviews.length,
                            itemBuilder: (context, index) {
                              final review = reviews[index];
                              final user = review['usuarios'];
                              final isCurrentUser = user?['id'] == supabase.auth.currentUser?.id;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                                          child: Text(
                                            (user?['nome'] ?? 'U')[0].toUpperCase(),
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user?['nome'] ?? 'Usuário',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
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
                                        Row(
                                          children: List.generate(5, (starIndex) {
                                            return Icon(
                                              starIndex < (review['nota'] ?? 0)
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    if (review['comentario'] != null && review['comentario'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          review['comentario'],
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    if (isCurrentUser)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: _showRatingDialog,
                                              child: const Text('Editar'),
                                            ),
                                            TextButton(
                                              onPressed: _deleteRating,
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: const Text('Excluir'),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}