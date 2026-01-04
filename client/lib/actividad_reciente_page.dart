import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
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

      // Obtener rol del usuario desde la API
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

      List<ActividadItem> actividades = [];
      final ahora = DateTime.now();
      final hace7Dias = ahora.subtract(const Duration(days: 7));

      if (_userRole == 'cliente') {
        // CLIENTE: Cargar citas, reseñas y favoritos de los últimos 7 días
        
        // 1. Últimas citas
        try {
          final citasUrl = Uri.parse('$apiBaseUrl/citas/usuario/$userId');
          final citasResponse = await http.get(
            citasUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          ).timeout(const Duration(seconds: 5));

          if (citasResponse.statusCode == 200) {
            final List<dynamic> citas = json.decode(citasResponse.body);
            for (var cita in citas) {
              final fechaHora = cita['fecha_hora'] != null
                  ? DateTime.parse(cita['fecha_hora'])
                  : DateTime.now();

              // Solo incluir si es de los últimos 7 días
              if (fechaHora.isAfter(hace7Dias)) {
                final estado = cita['estado'] as String? ?? 'pendiente';
                String accion = '';
                IconData icono = Icons.event;
                Color color = AppTheme.primaryOrange;

                switch (estado) {
                  case 'confirmada':
                    accion = 'Cita confirmada';
                    icono = Icons.check_circle;
                    color = Colors.green;
                    break;
                  case 'cancelada':
                    accion = 'Cita cancelada';
                    icono = Icons.cancel;
                    color = Colors.red;
                    break;
                  case 'completada':
                    accion = 'Cita completada';
                    icono = Icons.done_all;
                    color = Colors.blue;
                    break;
                  default:
                    accion = 'Cita agendada';
                    icono = Icons.event_available;
                    color = AppTheme.primaryOrange;
                }

                actividades.add(ActividadItem(
                  icono: icono,
                  color: color,
                  accion: accion,
                  detalle: 'Con ${cita['comercio_nombre'] ?? 'Salón'}',
                  timestamp: fechaHora,
                ));
              }
            }
          }
        } catch (e) {
        }

        // 2. Últimas reseñas
        try {
          final resenasUrl = Uri.parse('$apiBaseUrl/api/resenas?usuario_id=$userId');
          final resenasResponse = await http.get(
            resenasUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          ).timeout(const Duration(seconds: 5));

          if (resenasResponse.statusCode == 200) {
            final List<dynamic> resenas = json.decode(resenasResponse.body);
            for (var resena in resenas) {
              final fechaCreacion = resena['fecha_creacion'] != null
                  ? DateTime.parse(resena['fecha_creacion'])
                  : DateTime.now();

              // Solo incluir si es de los últimos 7 días
              if (fechaCreacion.isAfter(hace7Dias)) {
                final calificacion = resena['calificacion'] as int? ?? 0;

                actividades.add(ActividadItem(
                  icono: Icons.rate_review,
                  color: Colors.amber,
                  accion: 'Reseña enviada',
                  detalle: '$calificacion ⭐ - ${resena['comercio_nombre'] ?? 'Salón'}',
                  timestamp: fechaCreacion,
                ));
              }
            }
          }
        } catch (e) {
        }

        // 3. Salones favoritos agregados
        try {
          final favoritosUrl = Uri.parse('$apiBaseUrl/api/favoritos/usuario/$userId');
          final favoritosResponse = await http.get(
            favoritosUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          ).timeout(const Duration(seconds: 5));

          if (favoritosResponse.statusCode == 200) {
            final List<dynamic> favoritos = json.decode(favoritosResponse.body);
            for (var favorito in favoritos) {
              final fechaCreacion = favorito['fecha_creacion'] != null
                  ? DateTime.parse(favorito['fecha_creacion'])
                  : DateTime.now();

              // Solo incluir si es de los últimos 7 días
              if (fechaCreacion.isAfter(hace7Dias)) {
                actividades.add(ActividadItem(
                  icono: Icons.favorite,
                  color: Colors.pink,
                  accion: 'Salón agregado a favoritos',
                  detalle: favorito['comercio_nombre'] ?? 'Salón',
                  timestamp: fechaCreacion,
                ));
              }
            }
          }
        } catch (e) {
        }

      } else {
        // SALON: Cargar citas recibidas y servicios creados
        
        // Obtener el comercio_id del salón
        String? comercioId;
        try {
          final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
          final comerciosResponse = await http.get(
            comerciosUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          ).timeout(const Duration(seconds: 5));

          if (comerciosResponse.statusCode == 200) {
            final List<dynamic> comercios = json.decode(comerciosResponse.body);
            for (var comercio in comercios) {
              if (comercio['uid_negocio'] == userId) {
                comercioId = comercio['id'];
                break;
              }
            }
          }
        } catch (e) {
        }

        if (comercioId != null) {
          // 1. Últimas citas agendadas (solo pendientes de los últimos 7 días)
          try {
            final citasUrl = Uri.parse('$apiBaseUrl/citas/comercio/$comercioId');
            final citasResponse = await http.get(
              citasUrl,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
            ).timeout(const Duration(seconds: 5));

            if (citasResponse.statusCode == 200) {
              final List<dynamic> citas = json.decode(citasResponse.body);
              
              // Solo mostrar citas pendientes de los últimos 7 días
              for (var cita in citas) {
                if (cita['estado'] == 'pendiente') {
                  final fechaHora = cita['fecha_hora'] != null
                      ? DateTime.parse(cita['fecha_hora'])
                      : DateTime.now();

                  // Solo incluir si es de los últimos 7 días
                  if (fechaHora.isAfter(hace7Dias)) {
                    actividades.add(ActividadItem(
                      icono: Icons.event_available,
                      color: AppTheme.primaryOrange,
                      accion: 'Nueva cita agendada',
                      detalle: 'Cliente: ${cita['usuario_nombre'] ?? 'Cliente'}',
                      timestamp: fechaHora,
                    ));
                  }
                }
              }
            }
          } catch (e) {
          }
        }
      }

      // Ordenar por fecha (más reciente primero)
      actividades.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _actividades.clear();
        _actividades.addAll(actividades);
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _procesarActividades(List<dynamic> actividadesData) {
    // Este método ya no se necesita
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
      return DateFormat('dd MMM yyyy', 'es').format(fecha);
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
