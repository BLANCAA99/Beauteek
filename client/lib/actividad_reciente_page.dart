import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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

      // Obtener rol del usuario
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final userData = userDoc.data()!;
      _userRole = userData['rol'] as String? ?? 'cliente';

      // Cargar actividades según el rol
      if (_userRole == 'salon') {
        await _cargarActividadSalon(user.uid);
      } else {
        await _cargarActividadCliente(user.uid);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error cargando actividad: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarActividadSalon(String uid) async {
    final List<ActividadItem> actividades = [];

    // Obtener comercioId
    final comercioSnapshot = await FirebaseFirestore.instance
        .collection('comercios')
        .where('dueno_id', isEqualTo: uid)
        .limit(1)
        .get();

    if (comercioSnapshot.docs.isEmpty) {
      setState(() => _actividades.clear());
      return;
    }

    final comercioId = comercioSnapshot.docs.first.id;

    // Cargar citas recientes (últimos 30 días)
    final hace30Dias = DateTime.now().subtract(const Duration(days: 30));
    final citasSnapshot = await FirebaseFirestore.instance
        .collection('citas')
        .where('comercio_id', isEqualTo: comercioId)
        .where('fecha_hora', isGreaterThanOrEqualTo: hace30Dias)
        .orderBy('fecha_hora', descending: true)
        .limit(20)
        .get();

    for (var doc in citasSnapshot.docs) {
      final data = doc.data();
      final fechaHora = (data['fecha_hora'] as Timestamp?)?.toDate() ?? DateTime.now();
      final estado = data['estado'] as String? ?? 'pendiente';

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
          accion = 'Nueva cita agendada';
          icono = Icons.event_available;
          color = AppTheme.primaryOrange;
      }

      actividades.add(ActividadItem(
        icono: icono,
        color: color,
        accion: accion,
        detalle: 'Servicio: ${data['servicio_nombre'] ?? 'Desconocido'}',
        timestamp: fechaHora,
      ));
    }

    // Cargar cambios en servicios recientes
    final serviciosSnapshot = await FirebaseFirestore.instance
        .collection('servicios')
        .where('comercio_id', isEqualTo: comercioId)
        .orderBy('creado_en', descending: true)
        .limit(5)
        .get();

    for (var doc in serviciosSnapshot.docs) {
      final data = doc.data();
      final creadoEn = (data['creado_en'] as Timestamp?)?.toDate() ?? DateTime.now();

      actividades.add(ActividadItem(
        icono: Icons.design_services,
        color: Colors.purple,
        accion: 'Servicio creado',
        detalle: data['nombre'] as String? ?? 'Servicio',
        timestamp: creadoEn,
      ));
    }

    // Ordenar por fecha descendente
    actividades.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _actividades.clear();
      _actividades.addAll(actividades.take(30));
    });
  }

  Future<void> _cargarActividadCliente(String uid) async {
    final List<ActividadItem> actividades = [];

    // Cargar citas del cliente (últimos 30 días)
    final hace30Dias = DateTime.now().subtract(const Duration(days: 30));
    final citasSnapshot = await FirebaseFirestore.instance
        .collection('citas')
        .where('cliente_id', isEqualTo: uid)
        .where('fecha_hora', isGreaterThanOrEqualTo: hace30Dias)
        .orderBy('fecha_hora', descending: true)
        .limit(20)
        .get();

    for (var doc in citasSnapshot.docs) {
      final data = doc.data();
      final fechaHora = (data['fecha_hora'] as Timestamp?)?.toDate() ?? DateTime.now();
      final estado = data['estado'] as String? ?? 'pendiente';

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
        detalle: 'Con ${data['comercio_nombre'] ?? 'Salón'}',
        timestamp: fechaHora,
      ));
    }

    // Cargar reseñas dejadas por el cliente
    final resenasSnapshot = await FirebaseFirestore.instance
        .collection('resenas')
        .where('cliente_id', isEqualTo: uid)
        .orderBy('fecha', descending: true)
        .limit(10)
        .get();

    for (var doc in resenasSnapshot.docs) {
      final data = doc.data();
      final fecha = (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
      final calificacion = data['calificacion'] as int? ?? 0;

      actividades.add(ActividadItem(
        icono: Icons.rate_review,
        color: Colors.amber,
        accion: 'Reseña enviada',
        detalle: '$calificacion ⭐ - ${data['comercio_nombre'] ?? 'Salón'}',
        timestamp: fecha,
      ));
    }

    // Ordenar por fecha descendente
    actividades.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _actividades.clear();
      _actividades.addAll(actividades.take(30));
    });
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
