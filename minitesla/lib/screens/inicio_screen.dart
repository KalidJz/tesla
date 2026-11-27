import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

class InicioScreen extends StatefulWidget {
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
  final bool live;
  final bool pulses;

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

  bool _btnPressed = false;

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  // Controlador continuo para el barrido de luz (shimmer) y el pulso del enlace
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    _ambient.dispose();
    super.dispose();
  }

  Color get _bateriaColor {
    if (_bateria > 50) return AppColors.success;
    if (_bateria > 20) return AppColors.warning;
    return AppColors.danger;
  }

  List<_Tele> get _telemetria => [
        _Tele(
          Icons.wifi_tethering,
          _enLinea ? 'MQTT' : 'Caída',
          'Conexión',
          _enLinea ? AppColors.accent : AppColors.danger,
          live: true,
          pulses: _enLinea,
        ),
        const _Tele(Icons.thermostat, '-- °C', 'Temp.', AppColors.warning),
        const _Tele(Icons.speed, '-- hPa', 'Presión', AppColors.violet),
        const _Tele(Icons.gps_fixed, '--', 'GPS', AppColors.success),
      ];

  Widget _staggered(double begin, double end, Widget child) {
    final anim = CurvedAnimation(
      parent: _enter,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.14),
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
        _staggered(0.0, 0.45, _heroPanel()),
        const SizedBox(height: 18),
        _staggered(0.32, 0.65, _linkPipelineCard()),
        const SizedBox(height: 24),
        _staggered(0.45, 0.78, _sectionTitle('MÓDULOS DEL SISTEMA')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _staggered(
                0.50,
                0.85,
                _moduleTile(
                  icon: Icons.analytics_outlined,
                  title: 'Análisis',
                  subtitle: 'Gráficas',
                  color: AppColors.violet,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _staggered(
                0.60,
                0.92,
                _moduleTile(
                  icon: Icons.map_outlined,
                  title: 'Monitoreo',
                  subtitle: 'Mapa GPS',
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _staggered(
                0.70,
                1.0,
                _moduleTile(
                  icon: Icons.memory,
                  title: 'Gateway',
                  subtitle: '433 MHz',
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Center(
          child: TextButton.icon(
            onPressed: () => _mostrarCreditos(context),
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text('Acerca del proyecto'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Panel principal ─────────────────────────

  Widget _heroPanel() {
    final statusColor = _enLinea ? AppColors.accent : AppColors.danger;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: statusColor.withAlpha(65)),
        gradient: const LinearGradient(
          colors: [AppColors.surfaceHigh, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withAlpha(24),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Resplandor ambiental sutil en la esquina superior izquierda
          Positioned(
            top: -50,
            left: -40,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      statusColor.withAlpha((34 + 18 * _pulse.value).round()),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Cuadrícula de puntos + línea de escaneo muy sutil
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambient,
              builder: (_, __) => CustomPaint(
                painter: _DotGridPainter(
                  scanProgress: _ambient.value,
                  scanColor: statusColor,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _headerRow(),
                const SizedBox(height: 18),
                _telemetryStrip(),
                const SizedBox(height: 18),
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
        // Medidor circular con ticks y punta luminosa
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _bateria / 100),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return SizedBox(
              width: 98,
              height: 98,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(98, 98),
                    painter: _GaugePainter(
                      value: value,
                      color: _bateriaColor,
                      stroke: 8,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Icon(
                          Icons.bolt_rounded,
                          color: _bateriaColor
                              .withAlpha((180 + 75 * _pulse.value).round()),
                          size: 17,
                        ),
                      ),
                      Text(
                        '${(value * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      const Text(
                        'BAT',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mi carrito',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  _signalBars(),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bg.withAlpha(140),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border.withAlpha(140)),
                ),
                child: const Text(
                  'ESP32-ROBOT-01',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.9,
                  ),
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

  // Barras de señal animadas
  Widget _signalBars() {
    final activeColor = _enLinea ? AppColors.success : AppColors.danger;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final active = _enLinea && i < 3;
            final extra = active && i == 2 ? (2.0 * _pulse.value) : 0.0;
            return Container(
              width: 3.5,
              height: 6.0 + i * 3.5 + extra,
              margin: const EdgeInsets.only(left: 2.5),
              decoration: BoxDecoration(
                color: active ? activeColor : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _statusPill() {
    final color = _enLinea ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(70)),
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
                          color: color.withAlpha((120 * (1 - v)).round()),
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
          const SizedBox(width: 5),
          Text(
            _enLinea ? 'En línea · Listo' : 'Sin conexión',
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

  // Franja de telemetría con íconos en cápsulas iluminadas
  Widget _telemetryStrip() {
    final items = _telemetria;
    final children = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(Container(
          width: 1,
          height: 38,
          color: AppColors.border.withAlpha(140),
        ));
      }
      children.add(Expanded(
        child: _staggered(0.18 + i * 0.08, 0.55 + i * 0.08, _teleItem(items[i])),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.bg.withAlpha(135),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withAlpha(150)),
      ),
      child: Row(children: children),
    );
  }

  Widget _teleItem(_Tele t) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final double opacity = t.live
            ? (t.pulses ? 0.7 + 0.3 * _pulse.value : 1.0)
            : 0.4 + 0.35 * _pulse.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: t.color.withAlpha(t.live ? 30 : 16),
                shape: BoxShape.circle,
              ),
              child: Opacity(
                opacity: opacity,
                child: Icon(t.icon, color: t.color, size: 19),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    t.live ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 12.5,
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
                fontSize: 10,
              ),
            ),
          ],
        );
      },
    );
  }

  // Botón con shimmer animado y respuesta táctil
  Widget _controlButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _btnPressed = true),
      onTapUp: (_) {
        setState(() => _btnPressed = false);
        widget.onNavigateToGestion();
      },
      onTapCancel: () => setState(() => _btnPressed = false),
      child: AnimatedScale(
        scale: _btnPressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          height: 52,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [AppColors.accent, Color(0xFF3B82F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withAlpha(_btnPressed ? 30 : 75),
                blurRadius: _btnPressed ? 8 : 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Destello diagonal periódico
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ambient,
                  builder: (_, __) {
                    final t = _ambient.value;
                    // El destello cruza en el primer 35% del ciclo
                    final pos = (t < 0.35) ? (t / 0.35) * 2.4 - 0.7 : 2.0;
                    return FractionallySizedBox(
                      alignment: Alignment(pos, 0),
                      widthFactor: 0.32,
                      child: Transform.rotate(
                        angle: 0.35,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withAlpha(0),
                                Colors.white.withAlpha(65),
                                Colors.white.withAlpha(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sports_esports_rounded,
                        color: AppColors.bg, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Controlar carrito',
                      style: TextStyle(
                        color: AppColors.bg,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Transform.translate(
                        offset: Offset(3.0 * _pulse.value, 0),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.bg,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────── Diagrama de enlace IoT animado ───────────────────

  Widget _linkPipelineCard() {
    final activeColor = _enLinea ? AppColors.accent : AppColors.border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withAlpha(160)),
      ),
      child: Row(
        children: [
          _pipeNode(Icons.smartphone_rounded, 'App', AppColors.accent),
          _pipeConnector(activeColor, 0.0),
          _pipeNode(Icons.cloud_done_outlined, 'MQTT', AppColors.violet),
          _pipeConnector(activeColor, 0.33),
          _pipeNode(Icons.router_outlined, 'Gateway', AppColors.warning),
          _pipeConnector(activeColor, 0.66),
          _pipeNode(Icons.smart_toy_outlined, 'Rover', AppColors.success),
        ],
      ),
    );
  }

  Widget _pipeNode(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _pipeConnector(Color color, double phase) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AnimatedBuilder(
          animation: _ambient,
          builder: (_, __) {
            final p = (_ambient.value + phase) % 1.0;
            return LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth;
                return SizedBox(
                  height: 8,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 1.5,
                        color: AppColors.border.withAlpha(150),
                      ),
                      if (_enLinea)
                        Positioned(
                          left: (w - 6).clamp(0, w) * p,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withAlpha(160),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────── Módulos ─────────────────────────

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _moduleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Módulo $title'),
              duration: const Duration(milliseconds: 900),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withAlpha(170)),
            gradient: LinearGradient(
              colors: [color.withAlpha(22), AppColors.surface],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(85)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Créditos ─────────────────────────

  void _mostrarCreditos(BuildContext context) {
    const team = [
      ('KJ', 'Kalid Hecoch Juárez Zenil', AppColors.accent),
      ('DG', 'David Antonio Gutiérrez Santana', AppColors.violet),
      ('CL', 'Carlos Alexis López Jiménez', AppColors.success),
      ('JJ', 'Jonathan Jaimes', AppColors.warning),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg.withAlpha(120),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withAlpha(150)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.school_outlined, color: AppColors.accent, size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Universidad de Colima',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                        Text(
                          'Facultad de Telemática',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'EQUIPO DE DESARROLLO',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            for (final (initials, name, color) in team)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withAlpha(28),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withAlpha(110)),
                      ),
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
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

/// Medidor circular de 270° con marcas de escala y punta luminosa.
class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final double stroke;

  _GaugePainter({
    required this.value,
    required this.color,
    this.stroke = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const start = 0.75 * math.pi;
    const sweep = 1.5 * math.pi;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Marcas de graduación exteriores sutiles
    final tickPaint = Paint()
      ..color = AppColors.border.withAlpha(110)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const tickCount = 18;
    for (int i = 0; i <= tickCount; i++) {
      final angle = start + (sweep * i / tickCount);
      final inner = Offset(
        center.dx + (radius - stroke / 2 - 4) * math.cos(angle),
        center.dy + (radius - stroke / 2 - 4) * math.sin(angle),
      );
      final outer = Offset(
        center.dx + (radius - stroke / 2 - 1.5) * math.cos(angle),
        center.dy + (radius - stroke / 2 - 1.5) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Pista de fondo
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.border.withAlpha(150);
    canvas.drawArc(rect, start, sweep, false, track);

    final clamped = value.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    // Arco de progreso con degradado
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: [color.withAlpha(110), color],
        transform: const GradientRotation(start),
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep * clamped, false, progress);

    // Punto brillante en la punta del arco
    final tipAngle = start + sweep * clamped;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tip,
      stroke * 0.75,
      Paint()
        ..color = color.withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(tip, stroke * 0.34, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}

/// Cuadrícula de puntos con línea de escaneo vertical sutil.
class _DotGridPainter extends CustomPainter {
  final double scanProgress;
  final Color scanColor;

  _DotGridPainter({
    required this.scanProgress,
    required this.scanColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withAlpha(12);
    const spacing = 22.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }

    // Franja de escaneo suave
    final yScan = size.height * scanProgress;
    final scanRect = Rect.fromLTWH(0, yScan - 24, size.width, 48);
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          scanColor.withAlpha(0),
          scanColor.withAlpha(16),
          scanColor.withAlpha(0),
        ],
      ).createShader(scanRect);
    canvas.drawRect(scanRect, scanPaint);
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) =>
      old.scanProgress != scanProgress || old.scanColor != scanColor;
}