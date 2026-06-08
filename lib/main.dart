import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/feed.dart';
import 'pages/descobrir.dart';
import 'pages/perfil.dart';
import 'pages/login.dart';
import 'pages/cadastrar.dart';
import 'pages/detalhes_filmes.dart';
import 'pages/discover.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://qckweoxyduorzsxwhfel.supabase.co',
    anonKey: 'sb_publishable_Q0cQoDKWsbq4pCk-gf0AwA_3mp2Q79P',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineFeed',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/feed': (context) => const FeedScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/detalhe_filme': (context) => MovieDetailScreen(
          movieId: ModalRoute.of(context)?.settings.arguments as String,
        ),
      },
    );
  }
}