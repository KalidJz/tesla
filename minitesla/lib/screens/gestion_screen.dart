import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import '../app_theme.dart';

class GestionScreen extends StatefulWidget {
  const GestionScreen({super.key});

  @override
  State<GestionScreen> createState() => _GestionScreenState();
}

class _GestionScreenState extends State<GestionScreen>
    with TickerProviderStateMixin {
  String _currentCommand = 'detener';
  String _activeMode = 'manual'; // 'manual', 'linea', 'automatico'
  bool _isSendingRoute = false;
  bool _stopPressed = false;
  LatLng? _targetLocation;

  // Coordenadas iniciales (Centro de Colima)
  final LatLng _initialLocation = const LatLng(19.2499, -103.6977);
  final MapController _mapController = MapController();

  final String apiUrl = 'https://tesla-api-9n4d.onrender.com/api/robot/command';
  DateTime _lastRequestTime = DateTime.now();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final AnimationController _radar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    _radar.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _sendCommand(String comando, {String? modo}) async {
    final targetMode = modo ?? _activeMode;
    if (comando == _currentCommand && targetMode == 'manual' && modo == null) {
      return;
    }

    final now = DateTime.now();
    if (comando != 'detener' &&
        targetMode == 'manual' &&
        now.difference(_lastRequestTime).inMilliseconds < 120) {
      return;
    }

    if (targetMode == 'manual') {
      if (comando == 'detener') {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.lightImpact();
      }
      setState(() => _currentCommand = comando);
    } else if (targetMode == 'automatico') {
      HapticFeedback.mediumImpact();
      setState(() => _isSendingRoute = true);
    } else {
      HapticFeedback.mediumImpact();
    }

    _lastRequestTime = now;

    final Map<String, dynamic> payload = {
      'robot_id': 'ESP32-ROBOT-01',
      'comando': comando,
      'modo': targetMode,
    };

    if (targetMode == 'automatico' && _targetLocation != null) {
      payload['lat'] = _targetLocation!.latitude;
      payload['lng'] = _targetLocation!.longitude;
    }

    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (targetMode == 'automatico' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.bg, size: 20),
                SizedBox(width: 10),
                Text(
                  'Ruta GPS enviada al vehículo',
                  style: TextStyle(
                    color: AppColors.bg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error enviando comando: $e');
      if (targetMode == 'automatico' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Error al enviar la ruta',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (targetMode == 'automatico' && mounted) {
        setState(() => _isSendingRoute = false);
      }
    }
  }

  void _switchMode(String newMode) {
    if (_activeMode == newMode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _activeMode = newMode;
      if (newMode != 'manual') {
        _currentCommand = 'detener';
      }
    });

    if (newMode == 'linea') {
      _sendCommand('seguir', modo: 'linea');
    } else if (newMode == 'manual') {
      _sendCommand('detener', modo: 'manual');
    }
  }

  void _emergencyStop() {
    HapticFeedback.heavyImpact();
    setState(() {
      _activeMode = 'manual';
      _currentCommand = 'detener';
    });
    _sendCommand('detener', modo: 'manual');
  }

  void _onJoystickChanged(StickDragDetails details) {
    final x = details.x;
    final y = details.y;

    if (x.abs() < 0.2 && y.abs() < 0.2) {
      _sendCommand('detener', modo: 'manual');
      return;
    }

    if (y.abs() > x.abs()) {
      _sendCommand(y < 0 ? 'adelante' : 'atras', modo: 'manual');
    } else {
      _sendCommand(x < 0 ? 'izquierda' : 'derecha', modo: 'manual');
    }
  }

  Color get _commandColor {
    switch (_currentCommand) {
      case 'adelante':
      case 'atras':
        return AppColors.success;
      case 'izquierda':
      case 'derecha':
        return AppColors.accent;
      default:
        return AppColors.danger;
    }
  }

  IconData get _commandIcon {
    switch (_currentCommand) {
      case 'adelante':
        return Icons.north_rounded;
      case 'atras':
        return Icons.south_rounded;
      case 'izquierda':
        return Icons.west_rounded;
      case 'derecha':
        return Icons.east_rounded;
      default:
        return Icons.pan_tool_alt_outlined;
    }
  }

  double get _carTurns {
    switch (_currentCommand) {
      case 'derecha':
        return 0.25;
      case 'atras':
        return 0.5;
      case 'izquierda':
        return -0.25;
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.accent,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Control del vehículo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              'ESP32-ROBOT-01 · LoRa 433',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: StatusPill(label: 'En línea', color: AppColors.success),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildModeSelector(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: _buildCurrentModeView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentModeView() {
    switch (_activeMode) {
      case 'linea':
        return KeyedSubtree(
          key: const ValueKey('linea'),
          child: _buildLineMode(),
        );
      case 'automatico':
        return KeyedSubtree(
          key: const ValueKey('automatico'),
          child: _buildMapMode(),
        );
      default:
        return KeyedSubtree(
          key: const ValueKey('manual'),
          child: _buildManualMode(),
        );
    }
  }

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildModeTab('Manual', Icons.sports_esports_rounded,
              _activeMode == 'manual', () => _switchMode('manual')),
          _buildModeTab('Línea', Icons.route_rounded, _activeMode == 'linea',
              () => _switchMode('linea')),
          _buildModeTab('GPS', Icons.map_rounded, _activeMode == 'automatico',
              () => _switchMode('automatico')),
        ],
      ),
    );
  }

  Widget _buildModeTab(
    String text,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withAlpha(32)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.accent.withAlpha(110)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────── MODO MANUAL ───────────────────────

  Widget _buildManualMode() {
    final bool isMoving = _currentCommand != 'detener';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _commandColor.withAlpha(115)),
              gradient: LinearGradient(
                colors: [_commandColor.withAlpha(22), AppColors.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _commandColor.withAlpha(24),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _commandColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'COMANDO ACTUAL',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Row(
                          key: ValueKey(_currentCommand),
                          children: [
                            Icon(_commandIcon, color: _commandColor, size: 21),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _currentCommand.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _commandColor,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isMoving
                            ? 'Transmitiendo vía MQTT'
                            : 'Motores en reposo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _directionPad(),
              ],
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              return SizedBox(
                width: 268,
                height: 268,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(268, 268),
                      painter: _RadarRingPainter(
                        color: _commandColor,
                        pulse: _pulse.value,
                        isActive: isMoving,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceHigh,
                        border: Border.all(
                          color: isMoving
                              ? _commandColor.withAlpha(140)
                              : AppColors.border,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _commandColor.withAlpha(isMoving ? 55 : 18),
                            blurRadius: isMoving ? 36 : 24,
                            spreadRadius: isMoving ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Joystick(
                        mode: JoystickMode.all,
                        listener: _onJoystickChanged,
                        onStickDragEnd: () =>
                            _sendCommand('detener', modo: 'manual'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Spacer(),
          _buildEmergencyStopButton(),
        ],
      ),
    );
  }

  // ─────────────────────── MODO SEGUIDOR DE LÍNEA ───────────────────────

  Widget _buildLineMode() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.violet.withAlpha(120)),
              gradient: LinearGradient(
                colors: [AppColors.violet.withAlpha(26), AppColors.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.violet.withAlpha(32),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.violet
                            .withAlpha((110 + 90 * _pulse.value).round()),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      color: AppColors.violet,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SEGUIDOR DE LÍNEA ACTIVO',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sensores TCRT5000 (D3–D6) guiando el trayecto con evasión ultrasónica (< 18 cm).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildEmergencyStopButton(),
        ],
      ),
    );
  }

  Widget _buildEmergencyStopButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _stopPressed = true),
      onTapUp: (_) {
        setState(() => _stopPressed = false);
        _emergencyStop();
      },
      onTapCancel: () => setState(() => _stopPressed = false),
      child: AnimatedScale(
        scale: _stopPressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [AppColors.danger, Color(0xFFDC2626)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withAlpha(_stopPressed ? 35 : 85),
                blurRadius: _stopPressed ? 8 : 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop_circle_outlined, color: AppColors.bg, size: 24),
              SizedBox(width: 10),
              Text(
                'STOP DE EMERGENCIA',
                style: TextStyle(
                  color: AppColors.bg,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrow(IconData icon, String cmd) {
    final active = _currentCommand == cmd;
    return GestureDetector(
      onTapDown: (_) => _sendCommand(cmd, modo: 'manual'),
      onTapUp: (_) => _sendCommand('detener', modo: 'manual'),
      onTapCancel: () => _sendCommand('detener', modo: 'manual'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 38,
        height: 38,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color:
              active ? _commandColor.withAlpha(45) : AppColors.bg.withAlpha(150),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active ? _commandColor : AppColors.border.withAlpha(170),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: _commandColor.withAlpha(70), blurRadius: 10)]
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? _commandColor : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _directionPad() {
    final bool isMoving = _currentCommand != 'detener';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _arrow(Icons.keyboard_arrow_up_rounded, 'adelante'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _arrow(Icons.keyboard_arrow_left_rounded, 'izquierda'),
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.bg.withAlpha(170),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _commandColor.withAlpha(isMoving ? 140 : 80),
                ),
              ),
              child: AnimatedRotation(
                turns: _carTurns,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: AnimatedScale(
                  scale: isMoving ? 1.08 : 0.96,
                  duration: const Duration(milliseconds: 180),
                  child: CustomPaint(
                    painter: _MiniRoverPainter(
                      accentColor: _commandColor,
                      isMoving: isMoving,
                    ),
                  ),
                ),
              ),
            ),
            _arrow(Icons.keyboard_arrow_right_rounded, 'derecha'),
          ],
        ),
        _arrow(Icons.keyboard_arrow_down_rounded, 'atras'),
      ],
    );
  }

  // ─────────────────────── MODO AUTOMÁTICO (GPS) ───────────────────────

  Widget _buildMapMode() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialLocation,
            initialZoom: 15.0,
            onTap: (tapPosition, point) {
              HapticFeedback.lightImpact();
              setState(() => _targetLocation = point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.robot.control',
              tileBuilder: (context, widget, tile) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -1, 0, 0, 0, 255,
                    0, -1, 0, 0, 255,
                    0, 0, -1, 0, 255,
                    0, 0, 0, 1, 0,
                  ]),
                  child: widget,
                );
              },
            ),
            MarkerLayer(
              markers: [
                if (_targetLocation != null)
                  Marker(
                    point: _targetLocation!,
                    width: 76,
                    height: 76,
                    child: AnimatedBuilder(
                      animation: _radar,
                      builder: (_, __) {
                        final v = _radar.value;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 24 + 48 * v,
                              height: 24 + 48 * v,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.danger
                                    .withAlpha((110 * (1 - v)).round()),
                                border: Border.all(
                                  color: AppColors.danger
                                      .withAlpha((180 * (1 - v)).round()),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.danger,
                              size: 40,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 14,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(235),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (_targetLocation != null
                        ? AppColors.success
                        : AppColors.accent)
                    .withAlpha(110),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(90),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: (_targetLocation != null
                            ? AppColors.success
                            : AppColors.accent)
                        .withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _targetLocation == null
                        ? Icons.touch_app_rounded
                        : Icons.gps_fixed_rounded,
                    color: _targetLocation == null
                        ? AppColors.accent
                        : AppColors.success,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _targetLocation == null
                            ? 'SELECCIONAR DESTINO'
                            : 'COORDENADAS LISTAS',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _targetLocation == null
                            ? 'Toca cualquier punto del mapa'
                            : '${_targetLocation!.latitude.toStringAsFixed(5)}, ${_targetLocation!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_targetLocation != null)
                  IconButton(
                    tooltip: 'Limpiar destino',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _targetLocation = null);
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: _targetLocation != null ? 90 : 24,
          child: FloatingActionButton.small(
            heroTag: 'recenter_map',
            backgroundColor: AppColors.surface.withAlpha(235),
            foregroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.border.withAlpha(180)),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              _mapController.move(_initialLocation, 15.0);
            },
            child: const Icon(Icons.my_location_rounded, size: 20),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            offset:
                _targetLocation != null ? Offset.zero : const Offset(0, 1.5),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _targetLocation != null ? 1.0 : 0.0,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: (_targetLocation == null || _isSendingRoute)
                      ? null
                      : () => _sendCommand('ir_coordenada', modo: 'automatico'),
                  icon: _isSendingRoute
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.bg,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(
                    _isSendingRoute ? 'ENVIANDO RUTA...' : 'ENVIAR RUTA',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bg,
                    disabledBackgroundColor: AppColors.accent.withAlpha(140),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 10,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Painters ─────────────────────────

class _RadarRingPainter extends CustomPainter {
  final Color color;
  final double pulse;
  final bool isActive;

  _RadarRingPainter({
    required this.color,
    required this.pulse,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = (isActive ? color : AppColors.border)
          .withAlpha(isActive ? (70 + 45 * pulse).round() : 90);
    canvas.drawCircle(center, maxR - 4, outerPaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.border.withAlpha(70);
    canvas.drawCircle(center, maxR - 20, innerPaint);

    final tickPaint = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = (isActive ? color : AppColors.textSecondary)
          .withAlpha(isActive ? 170 : 90);

    for (int i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2);
      final p1 = Offset(
        center.dx + (maxR - 14) * math.cos(angle),
        center.dy + (maxR - 14) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (maxR - 4) * math.cos(angle),
        center.dy + (maxR - 4) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarRingPainter old) =>
      old.color != color || old.pulse != pulse || old.isActive != isActive;
}

class _MiniRoverPainter extends CustomPainter {
  final Color accentColor;
  final bool isMoving;

  _MiniRoverPainter({
    required this.accentColor,
    required this.isMoving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    if (isMoving) {
      final beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [accentColor.withAlpha(140), accentColor.withAlpha(0)],
        ).createShader(Rect.fromLTWH(cx - 11, cy - 22, 22, 13));

      final beamPath = Path()
        ..moveTo(cx - 5, cy - 10)
        ..lineTo(cx - 11, cy - 21)
        ..lineTo(cx + 11, cy - 21)
        ..lineTo(cx + 5, cy - 10)
        ..close();
      canvas.drawPath(beamPath, beamPaint);
    }

    final wheelPaint = Paint()..color = const Color(0xFF1E293B);
    for (final dx in [-9.0, 6.0]) {
      for (final dy in [-8.5, 3.5]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + dx, cy + dy, 3.2, 5.5),
            const Radius.circular(1.5),
          ),
          wheelPaint,
        );
      }
    }

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 22),
      const Radius.circular(4.5),
    );
    canvas.drawRRect(bodyRect, Paint()..color = AppColors.surfaceHigh);
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = isMoving ? accentColor : AppColors.textSecondary,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 3.5), width: 9.5, height: 5),
        const Radius.circular(2),
      ),
      Paint()..color = accentColor.withAlpha(isMoving ? 190 : 90),
    );

    final frontLight = Paint()
      ..color =
          isMoving ? Colors.white : AppColors.textSecondary.withAlpha(120);
    canvas.drawCircle(Offset(cx - 4, cy - 9.5), 1.3, frontLight);
    canvas.drawCircle(Offset(cx + 4, cy - 9.5), 1.3, frontLight);

    final rearLight = Paint()
      ..color = isMoving ? AppColors.danger.withAlpha(90) : AppColors.danger;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 5, cy + 9.2, 3.2, 1.6),
        const Radius.circular(1),
      ),
      rearLight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 1.8, cy + 9.2, 3.2, 1.6),
        const Radius.circular(1),
      ),
      rearLight,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniRoverPainter old) =>
      old.accentColor != accentColor || old.isMoving != isMoving;
}