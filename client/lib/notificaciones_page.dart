import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';
import 'api_constants.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({Key? key}) : super(key: key);

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notificaciones = [];

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
  }

  Future<void> _cargarNotificaciones() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final idToken = await user.getIdToken();

      // 1. Obtener comercio del salón
      final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
      final comerciosResponse = await http.get(
        comerciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (comerciosResponse.statusCode != 200) {
        setState(() => _isLoading = false);
        return;
      }

      final List<dynamic> comercios = json.decode(comerciosResponse.body);
      final miComercio = comercios.firstWhere(
        (c) => c['uid_negocio'] == user.uid,
        orElse: () => null,
      );

      if (miComercio == null) {
        setState(() => _isLoading = false);
        return;
      }

      final comercioId = miComercio['id'];

      // 2. Obtener citas recientes (últimas 24 horas)
      final citasUrl = Uri.parse('$apiBaseUrl/citas?comercio_id=$comercioId');
      final citasResponse = await http.get(
        citasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (citasResponse.statusCode == 200) {
        final List<dynamic> citas = json.decode(citasResponse.body);
        final ahora = DateTime.now();
        final hace24Horas = ahora.subtract(const Duration(hours: 24));

        final List<Map<String, dynamic>> notificaciones = [];

        for (var cita in citas) {
          final fechaCita = DateTime.parse(cita['fecha_hora'].toString());
          final estado = cita['estado'] ?? '';

          // Notificaciones de citas nuevas (últimas 24h)
          if (fechaCita.isAfter(hace24Horas) && estado == 'pendiente') {
            notificaciones.add({
              'tipo': 'nueva_cita',
              'icon': Icons.event_available_rounded,
              'iconColor': const Color(0xFF34C759),
              'backgroundColor': const Color(0xFF0D2538),
              'titulo': 'Nueva cita agendada',
              'descripcion': '${_formatearFechaHora(fechaCita)}',
              'tiempo': _calcularTiempoTranscurrido(fechaCita),
              'fecha': fechaCita,
            });
          }

          // Notificaciones de citas canceladas
          if (estado == 'cancelada' && fechaCita.isAfter(hace24Horas)) {
            notificaciones.add({
              'tipo': 'cancelada',
              'icon': Icons.event_busy_rounded,
              'iconColor': AppTheme.primaryOrange,
              'backgroundColor': const Color(0xFF3B2612),
              'titulo': 'Cita cancelada',
              'descripcion': '${_formatearFechaHora(fechaCita)}',
              'tiempo': _calcularTiempoTranscurrido(fechaCita),
              'fecha': fechaCita,
            });
          }

          // Notificaciones de citas confirmadas
          if (estado == 'confirmada' && fechaCita.isAfter(hace24Horas)) {
            notificaciones.add({
              'tipo': 'confirmada',
              'icon': Icons.check_circle_rounded,
              'iconColor': const Color(0xFF34C759),
              'backgroundColor': const Color(0xFF0D2538),
              'titulo': 'Cita confirmada',
              'descripcion': '${_formatearFechaHora(fechaCita)}',
              'tiempo': _calcularTiempoTranscurrido(fechaCita),
              'fecha': fechaCita,
            });
          }

          // Recordatorios de citas próximas (próximas 2 horas)
          final dentroDeDoHoras = ahora.add(const Duration(hours: 2));
          if (fechaCita.isAfter(ahora) &&
              fechaCita.isBefore(dentroDeDoHoras) &&
              estado == 'confirmada') {
            notificaciones.add({
              'tipo': 'recordatorio',
              'icon': Icons.notifications_active_rounded,
              'iconColor': const Color(0xFF007AFF),
              'backgroundColor': const Color(0xFF0B1F2E),
              'titulo': 'Cita próxima',
              'descripcion': 'En ${_calcularTiempoHasta(fechaCita)}',
              'tiempo': 'Próximamente',
              'fecha': fechaCita,
            });
          }
        }

        // Ordenar por fecha (más reciente primero)
        notificaciones.sort((a, b) =>
            (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));

        setState(() {
          _notificaciones = notificaciones;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error cargando notificaciones: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatearFechaHora(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  String _calcularTiempoTranscurrido(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Justo ahora';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours}h';
    } else if (diferencia.inDays == 1) {
      return 'Ayer';
    } else {
      return 'Hace ${diferencia.inDays} días';
    }
  }

  String _calcularTiempoHasta(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = fecha.difference(ahora);

    if (diferencia.inMinutes < 60) {
      return '${diferencia.inMinutes} minutos';
    } else {
      return '${diferencia.inHours} horas';
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
          'Notificaciones',
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
          : _notificaciones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_outlined,
                        size: 64,
                        color: AppTheme.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay notificaciones',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarNotificaciones,
                  color: AppTheme.primaryOrange,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    itemCount: _notificaciones.length,
                    itemBuilder: (context, index) {
                      final notif = _notificaciones[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NotificacionCard(
                          icon: notif['icon'] as IconData,
                          iconColor: notif['iconColor'] as Color,
                          backgroundColor: notif['backgroundColor'] as Color,
                          titulo: notif['titulo'] as String,
                          descripcion: notif['descripcion'] as String,
                          tiempo: notif['tiempo'] as String,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotificacionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String titulo;
  final String descripcion;
  final String tiempo;

  const _NotificacionCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.titulo,
    required this.descripcion,
    required this.tiempo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            tiempo,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
