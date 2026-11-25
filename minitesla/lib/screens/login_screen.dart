import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;
  bool _hidePassword = true;

  final String baseUrl = 'http://127.0.0.1:8000/api';

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Por favor llena todos los campos');
      return;
    }

    if (!_isLogin && _nombreController.text.isEmpty) {
      _showSnackBar('Por favor ingresa tu nombre');
      return;
    }

    setState(() => _isLoading = true);

    final String endpoint = _isLogin ? '/login' : '/register';
    final Map<String, dynamic> body = _isLogin
        ? {
            'email': _emailController.text,
            'password': _passwordController.text,
          }
        : {
            'nombre': _nombreController.text,
            'email': _emailController.text,
            'password': _passwordController.text,
          };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (_isLogin) {
          final data = jsonDecode(response.body);
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString('user_id', data['user']['id'].toString());
          await prefs.setString('user_name', data['user']['nombre']);
          await prefs.setString('user_role', data['user']['rol']);

          if (mounted) Navigator.pushReplacementNamed(context, '/home');
        } else {
          _showSnackBar('Registro exitoso. Ahora inicia sesión.',
              color: AppColors.success);
          if (mounted) {
            setState(() {
              _isLogin = true;
              _passwordController.clear();
            });
          }
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showSnackBar(errorData['detail'] ?? 'Error en la solicitud');
      }
    } catch (e) {
      _showSnackBar('Error de conexión con el servidor');
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {Color color = AppColors.danger}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
              color: AppColors.bg, fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Fondo: cuadrícula de puntos + halos de luz
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter()),
          ),
          Positioned(
            top: -140,
            right: -110,
            child: _glow(AppColors.accent, 340, 70),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: _glow(AppColors.violet, 360, 55),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, 28 * (1 - v)),
                        child: child,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 22),
                        const Text(
                          'ENTORNO INTELIGENTE',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.25),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Text(
                            _isLogin ? 'Bienvenido de vuelta' : 'Crea tu cuenta',
                            key: ValueKey(_isLogin),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'Inicia sesión para controlar tu robot'
                              : 'Regístrate para empezar a controlar el robot',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildFormCard(),
                        const SizedBox(height: 28),
                        const Text(
                          'Universidad de Colima  ·  Facultad de Telemática',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Widgets ─────────────────────────

  Widget _glow(Color color, double size, int alpha) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withAlpha(alpha), color.withAlpha(0)],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(60),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bg,
        ),
        child: const Icon(
          Icons.smart_toy_outlined,
          size: 44,
          color: AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(215),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isLogin
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildTextField(
                      controller: _nombreController,
                      label: 'Nombre completo',
                      icon: Icons.person_outline,
                    ),
                  ),
          ),
          _buildTextField(
            controller: _emailController,
            label: 'Correo electrónico',
            icon: Icons.alternate_email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _passwordController,
            label: 'Contraseña',
            icon: Icons.lock_outline,
            obscureText: _hidePassword,
            suffix: IconButton(
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            ),
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _isLoading ? null : _toggleMode,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text.rich(
              TextSpan(
                text: _isLogin ? '¿No tienes cuenta? ' : '¿Ya tienes cuenta? ',
                style: const TextStyle(fontSize: 14),
                children: [
                  TextSpan(
                    text: _isLogin ? 'Regístrate' : 'Inicia sesión',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return Opacity(
      opacity: _isLoading ? 0.7 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [AppColors.accent, Color(0xFF3B82F6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withAlpha(70),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isLoading ? null : _submit,
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.bg,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isLogin ? 'Ingresar' : 'Crear cuenta',
                          style: const TextStyle(
                            color: AppColors.bg,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: AppColors.bg, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.accent),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.bg.withAlpha(160),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.accent, 1.5),
      ),
    );
  }
}

/// Cuadrícula de puntos sutil para el fondo.
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withAlpha(14);
    const spacing = 28.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}