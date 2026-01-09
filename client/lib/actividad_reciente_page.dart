import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'theme/app_theme.dart';

class ActividadItem {
  final IconData icono;
  final Color color;
  final String accion;
  final String detalle;
  final DateTime timestamp;

  ActividadItem({
    required this.icono,
    required this.color,
    required this.accion,
    required this.detalle,
    required this.timestamp,
  });

  factory ActividadItem.fromJson(Map<String, dynamic> json) {
    return ActividadItem(
      icono: _mapearIcono(json['icono'] as String? ?? 'event'),
      color: _parseColor(json['color'] as String? ?? '#EA963A'),
      accion: json['accion'] as String? ?? 'Actividad',
      detalle: json['detalle'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  static IconData _mapearIcono(String nombreIcono) {
    const iconos = {
      'check_circle': Icons.check_circle,
      'cancel': Icons.cancel,
      'done_all': Icons.done_all,
      'event_available': Icons.event_available,
      'rate_review': Icons.rate_review,
      'favorite': Icons.favorite,
      'event': Icons.event,
      'local_offer': Icons.local_offer,
      'add_photo_alternate': Icons.add_photo_alternate,
    };
    return iconos[nombreIcono] ?? Icons.event;
  }

  static Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }
}

class ActividadRecientePage extends StatefulWidget {
  const ActividadRecientePage({Key? key}) : super(key: key);

  @override
  State<ActividadRecientePage> createState() => _ActividadRecientePageState();
}

class _ActividadRecientePageState extends State<ActividadRecientePage> {
  final List<ActividadItem> _actividades = [];
  bool _isLoading = true;
  String _userRole = 'cliente';

  @override
  void initState() {
    super.initState();
    _cargarActividad();
  }

  Future<void> _cargarActividad() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final idToken = await user.getIdToken();
      final userId = user.uid;

      // Obtener rol del usuario
      final userUrl = Uri.parse('$apiBaseUrl/api/users/uid/$userId');
      final userResponse = await http.get(
        userUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (userResponse.statusCode != 200) {
        setState(() => _isLoading = false);
        return;
      }

      final userData = json.decode(userResponse.body);
      _userRole = userData['rol'] as String? ?? 'cliente';

      // Llamar al endpoint de actividad con el rol
      final actividadUrl = Uri.parse('$apiBaseUrl/api/actividad/$userId?rol=$_userRole');
      final actividadResponse = await http.get(
        actividadUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (actividadResponse.statusCode == 200) {
        final List<dynamic> actividadJson = json.decode(actividadResponse.body);
        final List<ActividadItem> actividades = actividadJson
            .map((item) => ActividadItem.fromJson(item as Map<String, dynamic>))
            .toList();

        setState(() {
          _actividades.clear();
          _actividades.addAll(actividades);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Hace un momento';
    } else if (diferencia.inHours < 1) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    } else if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} días';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Actividad Reciente',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : _actividades.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 80,
                        color: AppTheme.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay actividad reciente',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarActividad,
                  color: AppTheme.primaryOrange,
                  backgroundColor: AppTheme.cardBackground,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _actividades.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final actividad = _actividades[index];
                      return _ActividadCard(
                        actividad: actividad,
                        tiempoRelativo: _formatearFecha(actividad.timestamp),
                      );
                    },
                  ),
                ),
    );
  }
}

class _ActividadCard extends StatelessWidget {
  final ActividadItem actividad;
  final String tiempoRelativo;

  const _ActividadCard({
    required this.actividad,
    required this.tiempoRelativo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: actividad.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              actividad.icono,
              color: actividad.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actividad.accion,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  actividad.detalle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tiempoRelativo,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
