import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import 'gestion_screen.dart';
import 'inicio_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _userName = '';

  static const _titles = ['Inicio', 'Análisis', 'Monitoreo'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _userName = prefs.getString('user_name') ?? 'Usuario');
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _openGestion() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GestionScreen()),
    );
  }

  Widget _placeholder(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          Center(
            child: Text(
              _userName,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            color: AppColors.surfaceHigh,
            onSelected: (v) {
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: AppColors.danger),
                    SizedBox(width: 10),
                    Text('Cerrar sesión'),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent.withAlpha(40),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          InicioScreen(onNavigateToGestion: _openGestion),
          _placeholder(Icons.analytics_outlined, 'Análisis (en construcción)'),
          _placeholder(Icons.map_outlined, 'Monitoreo (en construcción)'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.accent),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: AppColors.accent),
            label: 'Análisis',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: AppColors.accent),
            label: 'Monitoreo',
          ),
        ],
      ),
    );
  }
}