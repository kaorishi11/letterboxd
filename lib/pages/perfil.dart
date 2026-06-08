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
  List<Map<String, dynamic>> suggestedUsers = [];
  bool isLoading = true;
  bool isEditing = false;
  bool isLoadingSuggestions = false;
  
  // Controllers para edição
  final TextEditingController nameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController photoUrlController = TextEditingController();
  
  // Estatísticas
  int moviesWatched = 0;
  int followers = 0;
  int following = 0;

  // Cores da paleta (igual ao feed)
  final Color backgroundColor = const Color(0xFFF3EEC8);
  final Color primaryColor = const Color(0xFF473835);
  final Color accentColor = const Color(0xFFB85C5A);

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    photoUrlController.dispose();
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
      // Carregar dados do usuário do banco
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
        photoUrlController.text = userData?['foto_perfil'] ?? '';
      }

      // Carregar avaliações do usuário do banco
      final reviewsResponse = await supabase
          .from('avaliacoes')
          .select('''
            id,
            comentario,
            nota,
            created_at,
            filmes (id, titulo, poster_url, ano, genero, descricao)
          ''')
          .eq('usuario_id', currentUser.id)
          .order('created_at', ascending: false);

      setState(() {
        userReviews = List<Map<String, dynamic>>.from(reviewsResponse);
        moviesWatched = userReviews.length;
      });

      // Carregar seguidores do banco
      final followersResponse = await supabase
          .from('seguidores')
          .select('id')
          .eq('seguindo_id', currentUser.id);
      
      setState(() {
        followers = followersResponse.length;
      });

      // Carregar seguindo do banco
      final followingResponse = await supabase
          .from('seguidores')
          .select('id')
          .eq('seguidor_id', currentUser.id);
      
      setState(() {
        following = followingResponse.length;
      });

      // Carregar sugestões de perfis para seguir
      await loadSuggestedUsers(currentUser.id);

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

  Future<void> loadSuggestedUsers(String currentUserId) async {
    setState(() {
      isLoadingSuggestions = true;
    });

    try {
      // Buscar IDs dos usuários que o currentUser já segue
      final followingResponse = await supabase
          .from('seguidores')
          .select('seguindo_id')
          .eq('seguidor_id', currentUserId);
      
      final followingIds = followingResponse.map((e) => e['seguindo_id'] as String).toList();
      
      // Buscar usuários que não são o currentUser e que ele não segue
      // Limitar a 10 sugestões
      final query = supabase
          .from('usuarios')
          .select('id, nome, foto_perfil, bio')
          .neq('id', currentUserId)
          .limit(10);
      
      // Se ele segue alguém, excluir esses IDs
      if (followingIds.isNotEmpty) {
        // Nota: O Supabase não tem NOT IN diretamente, então fazemos a filtragem no app
        final response = await query;
        final allUsers = List<Map<String, dynamic>>.from(response);
        
        setState(() {
          suggestedUsers = allUsers.where((user) => !followingIds.contains(user['id'])).toList();
        });
      } else {
        final response = await query;
        setState(() {
          suggestedUsers = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar sugestões: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingSuggestions = false;
        });
      }
    }
  }

  Future<void> followUser(String userId, String userName) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await supabase.from('seguidores').insert({
        'seguidor_id': currentUser.id,
        'seguindo_id': userId,
      });

      // Atualizar estatísticas
      setState(() {
        following++;
      });

      // Remover da lista de sugestões
      setState(() {
        suggestedUsers.removeWhere((user) => user['id'] == userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Você começou a seguir $userName!')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao seguir usuário: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao seguir usuário: $e')),
        );
      }
    }
  }

  // Função para atualizar perfil (nome, bio e foto)
  Future<void> updateProfile() async {
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Atualizar no banco
      await supabase
          .from('usuarios')
          .update({
            'nome': nameController.text.trim(),
            'bio': bioController.text.trim(),
            'foto_perfil': photoUrlController.text.trim().isEmpty ? null : photoUrlController.text.trim(),
          })
          .eq('id', currentUser.id);

      // Atualizar dados locais
      setState(() {
        userData?['nome'] = nameController.text.trim();
        userData?['bio'] = bioController.text.trim();
        userData?['foto_perfil'] = photoUrlController.text.trim().isEmpty ? null : photoUrlController.text.trim();
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

  void _showReviewDetails(Map<String, dynamic> review) {
    final movie = review['filmes'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
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
                          movie?['poster_url'] ?? '',
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 250,
                              color: primaryColor.withOpacity(0.1),
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
                              movie?['titulo'] ?? 'Sem título',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (movie?['ano'] != null)
                                  Text(
                                    movie!['ano'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                if (movie?['ano'] != null && movie?['genero'] != null)
                                  const SizedBox(width: 8),
                                if (movie?['genero'] != null)
                                  Text(
                                    movie!['genero'].toString(),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '${review['nota']}/5',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (review['comentario'] != null && review['comentario'].toString().isNotEmpty) ...[
                          const Text(
                            'Minha avaliação:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              review['comentario'],
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        const Text(
                          'Sinopse',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          movie?['descricao'] ?? 'Nenhuma descrição disponível para este filme.',
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

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;
    
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Perfil'),
          backgroundColor: primaryColor,
          foregroundColor: backgroundColor,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: backgroundColor,
                ),
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
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            color: primaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
                      color: const Color(0xFFF3EEC8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        if (!isEditing)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFFF3EEC8), size: 22),
                            onPressed: () {
                              setState(() {
                                isEditing = true;
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.logout_outlined, color: Color(0xFFF3EEC8), size: 22),
                          onPressed: logout,
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
              onRefresh: loadUserData,
              color: primaryColor,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        
                        // Foto de Perfil
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: primaryColor,
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
                                      style: TextStyle(fontSize: 48, color: primaryColor),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Nome e Bio
                        if (!isEditing) ...[
                          Text(
                            userData?['nome'] ?? 'Usuário',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
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
                                  color: primaryColor.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ] else ...[
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
                                TextField(
                                  controller: photoUrlController,
                                  decoration: const InputDecoration(
                                    labelText: 'URL da Foto de Perfil',
                                    hintText: 'https://exemplo.com/minha-foto.jpg',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.url,
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
                                            photoUrlController.text = userData?['foto_perfil'] ?? '';
                                          });
                                        },
                                        child: const Text('Cancelar'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: updateProfile,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                        ),
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
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
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
                        ),
                        
                        const Divider(height: 32, thickness: 1),
                        
                        // Sugestões de Perfis para Seguir
                        if (suggestedUsers.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'SUGESTÕES PARA SEGUIR',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  '${suggestedUsers.length} perfis',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primaryColor.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: suggestedUsers.length,
                              itemBuilder: (context, index) {
                                final user = suggestedUsers[index];
                                return Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: primaryColor.withOpacity(0.1),
                                        backgroundImage: user['foto_perfil'] != null && user['foto_perfil'].toString().isNotEmpty
                                            ? NetworkImage(user['foto_perfil'])
                                            : null,
                                        child: (user['foto_perfil'] == null || user['foto_perfil'].toString().isEmpty)
                                            ? Text(
                                                (user['nome'] ?? 'U')[0].toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryColor,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        user['nome'] ?? 'Usuário',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: primaryColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      ElevatedButton(
                                        onPressed: () => followUser(user['id'], user['nome'] ?? 'usuário'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          minimumSize: const Size(0, 28),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                        ),
                                        child: const Text(
                                          'Seguir',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const Divider(height: 32, thickness: 1),
                        ],
                        
                        // Título da seção de filmes avaliados
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FILMES AVALIADOS',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                '${moviesWatched} filmes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryColor.withOpacity(0.5),
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
                                _showReviewDetails(review);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(12),
                                        ),
                                        child: Image.network(
                                          movie?['poster_url'] ?? '',
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: primaryColor.withOpacity(0.1),
                                              child: Icon(
                                                Icons.movie,
                                                size: 40,
                                                color: primaryColor.withOpacity(0.3),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
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
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: primaryColor,
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
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: primaryColor.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}