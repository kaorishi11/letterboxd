// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../componets/navbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> userReviews = [];
  bool isLoading = true;
  bool isEditing = false;
  
  // Controllers para edição
  final TextEditingController nameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  
  // Estatísticas
  int moviesWatched = 0;
  int followers = 0;
  int following = 0;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> loadUserData() async {
    setState(() {
      isLoading = true;
    });

    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Carregar dados do usuário
      final userResponse = await supabase
          .from('usuarios')
          .select('*')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (userResponse != null) {
        setState(() {
          userData = Map<String, dynamic>.from(userResponse);
        });
        nameController.text = userData?['nome'] ?? '';
        bioController.text = userData?['bio'] ?? '';
      }

      // Carregar avaliações do usuário
      final reviewsResponse = await supabase
          .from('avaliacoes')
          .select('''
            id,
            comentario,
            nota,
            created_at,
            filmes (id, titulo, poster_url, ano, genero)
          ''')
          .eq('usuario_id', currentUser.id)
          .order('created_at', ascending: false);

      setState(() {
        userReviews = List<Map<String, dynamic>>.from(reviewsResponse);
        moviesWatched = userReviews.length;
      });

      // TODO: Carregar seguidores e seguindo quando implementar tabelas de relacionamento
      // Por enquanto, valores mockados
      setState(() {
        followers = 128;
        following = 94;
      });

    } catch (e) {
      debugPrint('Erro ao carregar dados do perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> updateProfile() async {
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      await supabase
          .from('usuarios')
          .update({
            'nome': nameController.text,
            'bio': bioController.text,
          })
          .eq('id', currentUser.id);

      setState(() {
        userData?['nome'] = nameController.text;
        userData?['bio'] = bioController.text;
        isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao atualizar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar perfil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Você não está logado',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Faça login para ver seu perfil',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text('Fazer Login'),
              ),
            ],
          ),
        ),
        bottomNavigationBar: CustomNavbar(
          currentIndex: 2,
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, '/feed');
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/discover');
                break;
              case 2:
                break;
            }
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perfil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                setState(() {
                  isEditing = true;
                });
              },
              tooltip: 'Editar Perfil',
            ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: logout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadUserData,
              child: CustomScrollView(
                slivers: [
                  // Cabeçalho do Perfil
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        
                        // Foto de Perfil
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.deepPurple,
                                    width: 3,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundImage: userData?['foto_perfil'] != null && userData!['foto_perfil']!.isNotEmpty
                                      ? NetworkImage(userData!['foto_perfil']!)
                                      : null,
                                  child: (userData?['foto_perfil'] == null || userData!['foto_perfil']!.isEmpty)
                                      ? Text(
                                          (userData?['nome'] ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(fontSize: 48),
                                        )
                                      : null,
                                ),
                              ),
                              if (isEditing)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.deepPurple,
                                    radius: 18,
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      onPressed: () {
                                        // TODO: Implementar upload de foto
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Upload de foto em breve')),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Nome e Bio
                        if (!isEditing) ...[
                          Text(
                            userData?['nome'] ?? 'Usuário',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (userData?['bio'] != null && userData!['bio'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                userData!['bio'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ] else ...[
                          // Modo de edição
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: bioController,
                                  decoration: const InputDecoration(
                                    labelText: 'Bio',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            isEditing = false;
                                            nameController.text = userData?['nome'] ?? '';
                                            bioController.text = userData?['bio'] ?? '';
                                          });
                                        },
                                        child: const Text('Cancelar'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: updateProfile,
                                        child: const Text('Salvar'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Estatísticas
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              moviesWatched.toString(),
                              'Filmes\nAvaliados',
                            ),
                            _buildStatItem(
                              followers.toString(),
                              'Seguidores',
                            ),
                            _buildStatItem(
                              following.toString(),
                              'Seguindo',
                            ),
                          ],
                        ),
                        
                        const Divider(height: 32),
                        
                        // Título da seção de filmes avaliados
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Filmes Avaliados',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Ver todos',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  
                  // Grade de Filmes Avaliados
                  if (userReviews.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.movie_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Nenhum filme avaliado ainda',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Avalie filmes para vê-los aqui!',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.7,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final review = userReviews[index];
                            final movie = review['filmes'];
                            
                            return GestureDetector(
                              onTap: () {
                                _showMovieDetails(movie);
                              },
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Poster
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(8),
                                        ),
                                        child: Image.network(
                                          movie?['poster_url'] ?? '',
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.movie,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    
                                    // Nota e título
                                    Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              ...List.generate(5, (starIndex) {
                                                return Icon(
                                                  starIndex < (review['nota'] ?? 0)
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 12,
                                                );
                                              }),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            movie?['titulo'] ?? 'Sem título',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: userReviews.length,
                        ),
                      ),
                    ),
                  
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: CustomNavbar(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/feed');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/discover');
              break;
            case 2:
              break;
          }
        },
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showMovieDetails(Map<String, dynamic>? movie) {
    if (movie == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: Image.network(
                          movie['poster_url'] ?? '',
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 250,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.movie,
                                size: 80,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie['titulo'] ?? 'Sem título',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (movie['ano'] != null)
                                  Text(
                                    movie['ano'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                if (movie['ano'] != null && movie['genero'] != null)
                                  const SizedBox(width: 8),
                                if (movie['genero'] != null)
                                  Text(
                                    movie['genero'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sinopse',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          movie['descricao'] ?? 'Nenhuma descrição disponível para este filme.',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}