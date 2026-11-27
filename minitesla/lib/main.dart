import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Requerido para bloquear la orientación
import 'app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  // Obligatorio inicializar los bindings de Flutter antes de usar SystemChrome
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquea la aplicación exclusivamente en modo vertical (Portrait)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const RobotControlApp());
  });
}

class RobotControlApp extends StatelessWidget {
  const RobotControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entorno Inteligente',
      debugShowCheckedModeBanner: false, // Quita la etiqueta roja de "DEBUG"
      theme: AppTheme.dark,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}