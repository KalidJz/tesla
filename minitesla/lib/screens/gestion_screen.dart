import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../app_theme.dart'; // Asegúrate de que la ruta a tu theme sea correcta

class GestionScreen extends StatefulWidget {
  const GestionScreen({super.key});

  @override
  State<GestionScreen> createState() => _GestionScreenState();
}

class _GestionScreenState extends State<GestionScreen> {
  String _currentCommand = 'stop';
  bool _isMapMode = false;
  LatLng? _targetLocation;
  
  // Coordenadas iniciales (Centro de Colima)
  final LatLng _initialLocation = const LatLng(19.2499, -103.6977);

  // Cambia la IP si usas un teléfono físico
  final String apiUrl = 'http://127.0.0.1:8000/api/robot/command';
  DateTime _lastRequestTime = DateTime.now();

  Future<void> _sendCommand(String comando, {String modo = 'manual'}) async {
    if (comando == _currentCommand && modo == 'manual') return;

    final now = DateTime.now();
    if (comando != 'stop' && now.difference(_lastRequestTime).inMilliseconds < 200) {
      return;
    }

    setState(() => _currentCommand = comando);
    _lastRequestTime = now;

    final Map<String, dynamic> payload = {
      'robot_id': 'ESP32-ROBOT-01',
      'comando': comando,
      'modo': modo,
    };

    if (modo == 'automatico' && _targetLocation != null) {
      payload['lat'] = _targetLocation!.latitude;
      payload['lng'] = _targetLocation!.longitude;
    }

    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      
      if (modo == 'automatico' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ruta enviada al vehículo', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error enviando comando: $e');
    }
  }

  void _onJoystickChanged(StickDragDetails details) {
    final x = details.x;
    final y = details.y;

    if (x.abs() < 0.2 && y.abs() < 0.2) {
      _sendCommand('stop');
      return;
    }

    if (y.abs() > x.abs()) {
      _sendCommand(y < 0 ? 'adelante' : 'atras');
    } else {
      _sendCommand(x < 0 ? 'izquierda' : 'derecha');
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

  Widget _arrow(IconData icon, String cmd) {
    final active = _currentCommand == cmd;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 52,
      height: 52,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: active ? _commandColor.withAlpha(40) : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? _commandColor : AppColors.border,
        ),
      ),
      child: Icon(
        icon,
        color: active ? _commandColor : AppColors.textSecondary,
      ),
    );
  }

  Widget _directionPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _arrow(Icons.keyboard_arrow_up, 'adelante'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _arrow(Icons.keyboard_arrow_left, 'izquierda'),
            const SizedBox(width: 58, height: 58),
            _arrow(Icons.keyboard_arrow_right, 'derecha'),
          ],
        ),
        _arrow(Icons.keyboard_arrow_down, 'atras'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Control del vehículo'),
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
            // Selector de modo (Manual / Mapa)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _buildModeTab('Manual', Icons.gamepad, !_isMapMode, () => setState(() => _isMapMode = false)),
                  _buildModeTab('Automático', Icons.map, _isMapMode, () => setState(() => _isMapMode = true)),
                ],
              ),
            ),

            // Contenido dinámico
            Expanded(
              child: _isMapMode ? _buildMapMode() : _buildManualMode(),
            ),
          ],
        ),
      ),
    );
  }

  // Pestaña personalizada para el selector de modo
  Widget _buildModeTab(String text, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.accent.withAlpha(100) : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Interfaz de Control Manual (Joystick)
  Widget _buildManualMode() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          AppCard(
            borderColor: _commandColor.withAlpha(120),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COMANDO ACTUAL',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currentCommand.toUpperCase(),
                        style: TextStyle(
                          color: _commandColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _directionPad(),
              ],
            ),
          ),
          const Spacer(),
          
          // Joystick con diseño integrado
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceHigh,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withAlpha(15),
                  blurRadius: 40,
                  spreadRadius: 10,
                )
              ],
            ),
            child: Joystick(
              mode: JoystickMode.all,
              listener: _onJoystickChanged,
              onStickDragEnd: () => _sendCommand('stop'),
            ),
          ),
          const Spacer(),
          
          // Botón Stop de Emergencia
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: () => _sendCommand('stop'),
              icon: const Icon(Icons.stop_circle_outlined, size: 24),
              label: const Text('STOP DE EMERGENCIA', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Interfaz de Control Automático (Mapa)
  Widget _buildMapMode() {
    return Stack(
      children: [
        // Mapa base
        FlutterMap(
          options: MapOptions(
            initialCenter: _initialLocation,
            initialZoom: 15.0,
            onTap: (tapPosition, point) {
              setState(() => _targetLocation = point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.robot.control',
              // Filtro oscuro opcional para que el mapa haga juego con el tema dark
              tileBuilder: (context, widget, tile) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -1,  0,  0, 0, 255,
                     0, -1,  0, 0, 255,
                     0,  0, -1, 0, 255,
                     0,  0,  0, 1,   0,
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
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.location_on, color: AppColors.danger, size: 44),
                  ),
              ],
            ),
          ],
        ),
        
        // Tarjeta flotante superior (Instrucciones)
        Positioned(
          top: 16,
          left: 20,
          right: 20,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderColor: AppColors.accent.withAlpha(100),
            color: AppColors.surface.withAlpha(230),
            child: Row(
              children: [
                const Icon(Icons.touch_app, color: AppColors.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _targetLocation == null 
                        ? 'Toca el mapa para establecer el destino' 
                        : 'Destino: ${_targetLocation!.latitude.toStringAsFixed(4)}, ${_targetLocation!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Botón inferior flotante (Enviar Ruta)
        if (_targetLocation != null)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => _sendCommand('ir_coordenada', modo: 'automatico'),
                icon: const Icon(Icons.send_rounded, size: 20),
                label: const Text('ENVIAR RUTA', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 8,
                ),
              ),
            ),
          ),
      ],
    );
  }
}