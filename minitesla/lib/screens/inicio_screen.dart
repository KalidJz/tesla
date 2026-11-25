import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

class InicioScreen extends StatefulWidget {
  // Función que recibimos desde HomeScreen para abrir el control del carrito
  final VoidCallback onNavigateToGestion;

  const InicioScreen({super.key, required this.onNavigateToGestion});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _Tele {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool live; // true = ya hay dato real
  final bool pulses; // true = el ícono parpadea suave

  const _Tele(
    this.icon,
    this.value,
    this.label,
    this.color, {
    this.live = false,
    this.pulses = false,
  });
}

class _InicioScreenState extends State<InicioScreen>
    with TickerProviderStateMixin {
  // ── Datos de ejemplo: reemplázalos por los reales (MQTT / API) ──
  static const int _bateria = 85;
  static const bool _enLinea = true;

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Color get _bateriaColor {
    if (_bateria > 50) return AppColors.success;
    if (_bateria > 20) return AppColors.warning;
    return AppColors.danger;
  }

  List<_Tele> get _telemetria => [
        _Tele(
          Icons.wifi,
          _enLinea ? 'MQTT' : 'Caída',
          'Conexión',
          _enLinea ? AppColors.accent : AppColors.danger,
          live: true,
          pulses: _enLinea,
        ),
        const _Tele(
            Icons.thermostat, '-- °C', 'Temp.', AppColors.warning),
        const _Tele(Icons.speed, '-- hPa', 'Presión', AppColors.violet),
        const _Tele(
            Icons.location_on_outlined, '--', 'GPS', AppColors.success),
      ];

  // Entrada escalonada: fade + desplazamiento
  Widget _staggered(double begin, double end, Widget child) {
    final anim = CurvedAnimation(
      parent: _enter,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _staggered(0.0, 0.5, _heroPanel()),
        const SizedBox(height: 26),
        _staggered(0.45, 0.8, _sectionTitle('MÓDULOS')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _staggered(
                0.5,
                0.85,
                _moduleTile(
                    Icons.analytics_outlined, 'Análisis', AppColors.violet),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _staggered(
                0.6,
                0.95,
                _moduleTile(
                    Icons.map_outlined, 'Monitoreo', AppColors.success),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _staggered(
                0.7,
                1.0,
                _moduleTile(Icons.memory, 'Gateway', AppColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () => _mostrarCreditos(context),
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text('Acerca del proyecto'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Panel principal compacto ─────────────────────────

  Widget _heroPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        gradient: const LinearGradient(
          colors: [AppColors.surfaceHigh, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _headerRow(),
                const SizedBox(height: 16),
                _telemetryStrip(),
                const SizedBox(height: 16),
                _controlButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Row(
      children: [
        // Medidor pequeño animado
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _bateria / 100),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(92, 92),
                    painter: _GaugePainter(
                      value: value,
                      color: _bateriaColor,
                      stroke: 8,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: _bateriaColor, size: 15),
                      Text(
                        '${(value * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mi carrito',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'ESP32-ROBOT-01',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              _statusPill(),
            ],
          ),
        ),
      ],
    );
  }

  // Pastilla de estado con punto que emite pulso
  Widget _statusPill() {
    final color = _enLinea ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final v = _pulse.value;
              return SizedBox(
                width: 16,
                height: 16,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_enLinea)
                      Container(
                        width: 7 + 9 * v,
                        height: 7 + 9 * v,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withAlpha((110 * (1 - v)).round()),
                        ),
                      ),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Text(
            _enLinea ? 'En línea' : 'Sin conexión',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // Franja de telemetría: ícono + valor + etiqueta, integrados
  Widget _telemetryStrip() {
    final items = _telemetria;
    final children = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(Container(
          width: 1,
          height: 34,
          color: AppColors.border.withAlpha(170),
        ));
      }
      children.add(Expanded(
        child: _staggered(0.2 + i * 0.1, 0.55 + i * 0.1, _teleItem(items[i])),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg.withAlpha(110),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withAlpha(150)),
      ),
      child: Row(children: children),
    );
  }

  Widget _teleItem(_Tele t) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final double opacity;
        if (t.live) {
          opacity = t.pulses ? 0.65 + 0.35 * _pulse.value : 1.0;
        } else {
          // Esperando lectura: "respira" tenue
          opacity = 0.35 + 0.35 * _pulse.value;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: opacity,
              child: Icon(t.icon, color: t.color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              t.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.live
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _controlButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [AppColors.accent, Color(0xFF3B82F6)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(55),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onNavigateToGestion,
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_esports_outlined,
                    color: AppColors.bg, size: 22),
                SizedBox(width: 10),
                Text(
                  'Controlar carrito',
                  style: TextStyle(
                    color: AppColors.bg,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded,
                    color: AppColors.bg, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Componentes ─────────────────────────

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _moduleTile(IconData icon, String title, Color color) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarCreditos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.school_outlined, color: AppColors.accent),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Universidad de Colima',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Facultad de Telemática',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'EQUIPO DE DESARROLLO',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            for (final name in const [
              'Kalid Hecoch Juárez Zenil',
              'David Antonio Gutiérrez Santana',
              'Carlos Alexis López Jiménez',
              'Jonathan Jaimes',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
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
}

// ───────────────────────── Painters ─────────────────────────

/// Medidor circular de 270° con progreso redondeado.
class _GaugePainter extends CustomPainter {
  final double value; // 0.0 – 1.0
  final Color color;
  final double stroke;

  _GaugePainter({
    required this.value,
    required this.color,
    this.stroke = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const start = 0.75 * math.pi; // 135°
    const sweep = 1.5 * math.pi; // 270°

    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.border.withAlpha(160);
    canvas.drawArc(rect, start, sweep, false, track);

    if (value <= 0) return;

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: [color.withAlpha(120), color],
        transform: const GradientRotation(start),
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep * value.clamp(0.0, 1.0), false, progress);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}

/// Cuadrícula de puntos sutil para el fondo del panel.
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withAlpha(12);
    const spacing = 22.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}