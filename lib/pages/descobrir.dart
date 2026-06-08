import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../componets/navbar.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> allMovies = [];
  List<Map<String, dynamic>> filteredMovies = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadMovies();
    searchController.addListener(_filterMovies);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadMovies() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase
          .from('filmes')
          .select('id, titulo, poster_url, ano, genero, descricao')
          .order('titulo', ascending: true);

      setState(() {
        allMovies = List<Map<String, dynamic>>.from(response);
        filteredMovies = allMovies;
      });
    } catch (e) {
      debugPrint('Erro ao carregar filmes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar filmes: $e')),
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

  void _filterMovies() {
    final query = searchController.text.toLowerCase().trim();
    
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          filteredMovies = allMovies;
        } else {
          filteredMovies = allMovies.where((movie) {
            final title = movie['titulo']?.toString().toLowerCase() ?? '';
            final genre = movie['genero']?.toString().toLowerCase() ?? '';
            final year = movie['ano'] != null ? movie['ano'].toString() : '';
            
            return title.contains(query) || 
                   genre.contains(query) || 
                   year.contains(query);
          }).toList();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Descobrir',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () {
              _showFilterDialog();
            },
            tooltip: 'Filtrar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Campo de Busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar filmes por título, gênero ou ano...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[600]),
                          onPressed: () {
                            searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          
          // Resultados
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredMovies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.movie_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              searchController.text.isEmpty
                                  ? 'Nenhum filme encontrado'
                                  : 'Nenhum resultado para "${searchController.text}"',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (searchController.text.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  searchController.clear();
                                },
                                child: const Text('Limpar busca'),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadMovies,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.65,
                          ),
                          itemCount: filteredMovies.length,
                          itemBuilder: (context, index) {
                            final movie = filteredMovies[index];
                            return _buildMovieCard(movie);
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: CustomNavbar(
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/feed');
              break;
            case 1:
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
      ),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _showMovieDetails(movie);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  movie['poster_url'] ?? '',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.movie,
                        size: 50,
                        color: Colors.grey,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Informações
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie['titulo'] ?? 'Sem título',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (movie['ano'] != null)
                    Text(
                      movie['ano'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  if (movie['genero'] != null && movie['genero'].toString().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        movie['genero'].toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.deepPurple[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMovieDetails(Map<String, dynamic> movie) {
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
                  // Handle
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
                  
                  // Poster e título
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
                                if (movie['ano'] != null && movie['genero'] != null && movie['genero'].toString().isNotEmpty)
                                  const SizedBox(width: 8),
                                if (movie['genero'] != null && movie['genero'].toString().isNotEmpty)
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
                  
                  // Descrição
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
                        const SizedBox(height: 24),
                        
                        // Botão de ação
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Avaliar ${movie['titulo']} em breve'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.rate_review),
                                label: const Text('Avaliar Filme'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  void _showFilterDialog() {
    // Extrair gêneros únicos (não nulos e não vazios)
    final Set<String> genresSet = {};
    final Set<String> yearsSet = {};
    
    for (var movie in allMovies) {
      final genre = movie['genero']?.toString();
      if (genre != null && genre.isNotEmpty) {
        genresSet.add(genre);
      }
      
      final year = movie['ano'];
      if (year != null) {
        yearsSet.add(year.toString());
      }
    }
    
    final genres = genresSet.toList()..sort();
    final years = yearsSet.toList()..sort();
    
    showDialog(
      context: context,
      builder: (context) {
        String? selectedGenre;
        String? selectedYear;
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filtrar Filmes'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Gênero',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedGenre,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos')),
                        ...genres.map((genre) => DropdownMenuItem(
                              value: genre,
                              child: Text(genre),
                            )),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedGenre = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Ano',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedYear,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos')),
                        ...years.map((year) => DropdownMenuItem(
                              value: year,
                              child: Text(year),
                            )),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedYear = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      filteredMovies = allMovies.where((movie) {
                        bool matchesGenre = selectedGenre == null || 
                            (movie['genero']?.toString() == selectedGenre);
                        bool matchesYear = selectedYear == null || 
                            (movie['ano']?.toString() == selectedYear);
                        return matchesGenre && matchesYear;
                      }).toList();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}