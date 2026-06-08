// lib/pages/discover_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detalhes_filmes.dart';

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
  
  // Filtros
  String selectedGenre = 'Todos';
  String selectedYear = 'Todos';
  String searchQuery = '';
  
  List<String> genres = [];
  List<String> years = [];

  final Color backgroundColor = const Color(0xFFF3EEC8);
  final Color primaryColor = const Color(0xFF473835);
  final Color accentColor = const Color(0xFFB85C5A);

  @override
  void initState() {
    super.initState();
    loadMovies();
  }

  Future<void> loadMovies() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase
          .from('filmes')
          .select('*')
          .order('titulo');

      setState(() {
        allMovies = List<Map<String, dynamic>>.from(response);
        filteredMovies = allMovies;
        
        // Extrair gêneros únicos
        Set<String> genreSet = {};
        for (var movie in allMovies) {
          if (movie['genero'] != null && movie['genero'].toString().isNotEmpty) {
            genreSet.add(movie['genero'].toString());
          }
        }
        genres = genreSet.toList()..sort();
        genres.insert(0, 'Todos');
        
        // Extrair anos únicos
        Set<String> yearSet = {};
        for (var movie in allMovies) {
          if (movie['ano'] != null && movie['ano'] > 0) {
            yearSet.add(movie['ano'].toString());
          }
        }
        years = yearSet.toList()..sort((a, b) => b.compareTo(a));
        years.insert(0, 'Todos');
      });
    } catch (e) {
      debugPrint('Erro ao carregar filmes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar filmes: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void filterMovies() {
    setState(() {
      filteredMovies = allMovies.where((movie) {
        // Filtro por gênero
        if (selectedGenre != 'Todos' && movie['genero'] != selectedGenre) {
          return false;
        }
        
        // Filtro por ano
        if (selectedYear != 'Todos' && movie['ano'].toString() != selectedYear) {
          return false;
        }
        
        // Filtro por busca
        if (searchQuery.isNotEmpty) {
          final title = movie['titulo'].toString().toLowerCase();
          final desc = movie['descricao'].toString().toLowerCase();
          return title.contains(searchQuery.toLowerCase()) || 
                 desc.contains(searchQuery.toLowerCase());
        }
        
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'DESCUBRA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
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
              child: TextField(
                onChanged: (value) {
                  searchQuery = value;
                  filterMovies();
                },
                decoration: InputDecoration(
                  hintText: 'Buscar filmes...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),
          
          // Filtros ativos
          if (selectedGenre != 'Todos' || selectedYear != 'Todos')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (selectedGenre != 'Todos')
                      Chip(
                        label: Text(selectedGenre),
                        onDeleted: () {
                          setState(() {
                            selectedGenre = 'Todos';
                            filterMovies();
                          });
                        },
                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                        deleteIconColor: primaryColor,
                      ),
                    if (selectedYear != 'Todos')
                      Chip(
                        label: Text(selectedYear),
                        onDeleted: () {
                          setState(() {
                            selectedYear = 'Todos';
                            filterMovies();
                          });
                        },
                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                        deleteIconColor: primaryColor,
                      ),
                  ],
                ),
              ),
            ),
          
          // Resultados
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : filteredMovies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.movie_outlined,
                              size: 64,
                              color: primaryColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhum filme encontrado',
                              style: TextStyle(
                                fontSize: 16,
                                color: primaryColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredMovies.length,
                        itemBuilder: (context, index) {
                          final movie = filteredMovies[index];
                          return _buildMovieCard(movie);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailScreen(movieId: movie['id']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                movie['poster_url'] ?? '',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: primaryColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.movie,
                      size: 50,
                      color: primaryColor.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
            ),
            
            // Informações
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie['titulo'] ?? 'Sem título',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      movie['ano']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          _getMovieAverageRating(movie['id']).toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            movie['genero'] ?? 'Geral',
                            style: TextStyle(
                              fontSize: 10,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getMovieAverageRating(String movieId) {
    // Este método será implementado com dados reais do Supabase
    // Por enquanto retorna um valor aleatório
    return 4.2;
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtrar por',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gênero',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: genres.length,
                      itemBuilder: (context, index) {
                        final genre = genres[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(genre),
                            selected: selectedGenre == genre,
                            onSelected: (selected) {
                              setStateSheet(() {
                                selectedGenre = genre;
                              });
                              setState(() {
                                selectedGenre = genre;
                                filterMovies();
                              });
                            },
                            backgroundColor: primaryColor.withValues(alpha: 0.1),
                            selectedColor: primaryColor,
                            labelStyle: TextStyle(
                              color: selectedGenre == genre ? Colors.white : primaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ano',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: years.length,
                      itemBuilder: (context, index) {
                        final year = years[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(year),
                            selected: selectedYear == year,
                            onSelected: (selected) {
                              setStateSheet(() {
                                selectedYear = year;
                              });
                              setState(() {
                                selectedYear = year;
                                filterMovies();
                              });
                            },
                            backgroundColor: primaryColor.withValues(alpha: 0.1),
                            selectedColor: primaryColor,
                            labelStyle: TextStyle(
                              color: selectedYear == year ? Colors.white : primaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setStateSheet(() {
                              selectedGenre = 'Todos';
                              selectedYear = 'Todos';
                            });
                            setState(() {
                              selectedGenre = 'Todos';
                              selectedYear = 'Todos';
                              filterMovies();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor),
                          ),
                          child: const Text('Limpar filtros'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: backgroundColor,
                          ),
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}