import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'api_constants.dart';
import 'profile_menu.dart';
import 'calendar_page.dart';
import 'estadisticas_salon_page.dart';
import 'gestionar_promociones_page.dart';
import 'notificaciones_page.dart';
import 'theme/app_theme.dart';

class InicioSalonPage extends StatefulWidget {
  const InicioSalonPage({Key? key}) : super(key: key);

  @override
  State<InicioSalonPage> createState() => _InicioSalonPageState();
}

class _InicioSalonPageState extends State<InicioSalonPage> {
  bool _isLoading = true;
  String? _uidUsuario;
  String? _nombreSalon;
  String? _logoSalon;
  String? _comercioId;
  List<Map<String, dynamic>> _citasDelDia = [];
  List<Map<String, dynamic>> _promociones = [];
  List<Map<String, dynamic>> _resenas = [];
  int _citasPorConfirmar = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    await _obtenerDatosUsuario();
    await _cargarDatosSalon();
    if (_comercioId != null) {
      await Future.wait([
        _cargarCitasDelDia(),
        _cargarPromociones(),
        _cargarResenas(),
      ]);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _obtenerDatosUsuario() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        print('⚠️ No hay usuario autenticado');
        return;
      }

      setState(() {
        _uidUsuario = uid;
      });

      print('👤 Usuario salon: $_uidUsuario');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  Future<void> _cargarDatosSalon() async {
    try {
      if (_uidUsuario == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      final url = Uri.parse('$apiBaseUrl/comercios');

      print('🏢 Buscando comercios del salón: $_uidUsuario');

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          )
          .timeout(const Duration(seconds: 6));

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> comercios = json.decode(response.body);

        final miComercio = comercios.firstWhere(
          (c) => c['uid_negocio'] == _uidUsuario,
          orElse: () => null,
        );

        if (miComercio != null) {
          setState(() {
            _comercioId = miComercio['id'];
            _nombreSalon = miComercio['nombre'] ?? 'Mi Salón';
            _logoSalon = miComercio['foto_url'];
          });
          print('✅ Datos del salón cargados: $_nombreSalon (ID: $_comercioId)');
        } else {
          print('⚠️ No se encontró comercio para este usuario');
          setState(() {
            _nombreSalon = 'Mi Salón';
          });
        }
      }
    } catch (e) {
      print('❌ Error cargando datos del salón: $e');
      setState(() {
        _nombreSalon = 'Mi Salón';
      });
    }
  }

  Future<void> _cargarCitasDelDia() async {
    try {
      if (_comercioId == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final now = DateTime.now();
      final inicioDia = DateTime(now.year, now.month, now.day);
      final finDia = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final url = Uri.parse('$apiBaseUrl/citas?comercio_id=$_comercioId');
      print('🔍 Cargando citas del día para comercio $_comercioId');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> citasData = json.decode(response.body);

        // Filtrar citas de hoy y ordenar por hora
        final citasHoy = citasData.where((cita) {
          if (cita['fecha_hora'] == null) return false;
          try {
            final fechaCita = DateTime.parse(cita['fecha_hora']);
            return fechaCita.isAfter(inicioDia) && fechaCita.isBefore(finDia);
          } catch (e) {
            return false;
          }
        }).toList();

        citasHoy.sort((a, b) {
          final fechaA = DateTime.parse(a['fecha_hora']);
          final fechaB = DateTime.parse(b['fecha_hora']);
          return fechaA.compareTo(fechaB);
        });

        // Contar citas por confirmar
        final porConfirmar = citasHoy.where((c) => c['estado'] == 'pendiente').length;

        if (!mounted) return;

        setState(() {
          _citasDelDia = citasHoy.cast<Map<String, dynamic>>();
          _citasPorConfirmar = porConfirmar;
        });

        print('✅ Citas del día cargadas: ${_citasDelDia.length}, por confirmar: $_citasPorConfirmar');
      }
    } catch (e) {
      print('❌ Error cargando citas del día: $e');
    }
  }

  Future<void> _cargarPromociones() async {
    try {
      if (_comercioId == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/promociones/comercio/$_comercioId');
      print('🔍 Cargando promociones para comercio $_comercioId');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> promocionesData = json.decode(response.body);
        final now = DateTime.now();

        // Filtrar solo promociones activas
        final activas = promocionesData.where((promo) {
          if (promo['fecha_fin'] == null) return true;
          try {
            DateTime fechaFin;
            if (promo['fecha_fin'] is String) {
              fechaFin = DateTime.parse(promo['fecha_fin']);
            } else {
              fechaFin = DateTime.parse(promo['fecha_fin'].toString());
            }
            return fechaFin.isAfter(now);
          } catch (e) {
            print('⚠️ Error parsing fecha_fin: $e');
            return false;
          }
        }).toList();

        if (!mounted) return;

        setState(() {
          _promociones = activas.cast<Map<String, dynamic>>();
        });

        print('✅ Promociones activas cargadas: ${_promociones.length}');
      }
    } catch (e) {
      print('❌ Error cargando promociones: $e');
    }
  }

  Future<void> _cargarResenas() async {
    try {
      if (_comercioId == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/resenas?comercio_id=$_comercioId');
      print('🔍 Cargando reseñas para comercio $_comercioId');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> resenasData = json.decode(response.body);

        // Ordenar por fecha descendente y tomar las 3 más recientes
        resenasData.sort((a, b) {
          final fechaA = a['created_at'] != null
              ? DateTime.parse(a['created_at'])
              : DateTime(2000);
          final fechaB = b['created_at'] != null
              ? DateTime.parse(b['created_at'])
              : DateTime(2000);
          return fechaB.compareTo(fechaA);
        });

        final recientes = resenasData.take(3).toList();

        if (!mounted) return;

        setState(() {
          _resenas = recientes.cast<Map<String, dynamic>>();
        });

        print('✅ Reseñas recientes cargadas: ${_resenas.length}');
      }
    } catch (e) {
      print('❌ Error cargando reseñas: $e');
    }
  }

  String _obtenerSaludo() {
    final hora = DateTime.now().hour;

    if (hora >= 0 && hora < 12) {
      return 'Buenos días';
    } else if (hora >= 12 && hora < 19) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  String _obtenerFechaHoraActual() {
    final now = DateTime.now();
    final dias = [
      'Domingo',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado'
    ];
    final meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];

    final dia = dias[now.weekday % 7];
    final mes = meses[now.month - 1];
    final hora = now.hour.toString().padLeft(2, '0');
    final minuto = now.minute.toString().padLeft(2, '0');

    return '$dia, ${now.day} de $mes • $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: usar este botón después
        },
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileMenuPage(uid: uid),
                        ),
                      );
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _logoSalon == null
                            ? AppTheme.primaryGradient
                            : null,
                        image: _logoSalon != null
                            ? DecorationImage(
                                image: NetworkImage(_logoSalon!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _logoSalon == null
                          ? const Icon(
                              Icons.store,
                              color: Colors.white,
                              size: 28,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Línea de saludo + nombre del salón
                        Text(
                          '${_obtenerSaludo()}, ${_nombreSalon ?? 'Mi Salón'}',
                          style: AppTheme.heading3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Operaciones del día',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.logout,
                      color: AppTheme.errorRed,
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificacionesPage(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.notifications_none_outlined,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            // Contenido principal
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.primaryOrange),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fecha y hora actual (pill)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBackground,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: AppTheme.primaryOrange,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _obtenerFechaHoraActual(),
                                    style: AppTheme.bodyLarge.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Citas del día
                          Text(
                            'Citas del día',
                            style: AppTheme.heading2.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Timeline de citas dinámico
                          if (_citasDelDia.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: AppTheme.cardDecoration(borderRadius: 20),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.event_available,
                                      size: 48,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No hay citas programadas para hoy',
                                      style: AppTheme.bodyLarge.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._citasDelDia.asMap().entries.map((entry) {
                              final index = entry.key;
                              final cita = entry.value;
                              final esUltimo = index == _citasDelDia.length - 1;

                              final fechaHora = DateTime.parse(cita['fecha_hora']);
                              final horaFormato = DateFormat('HH:mm').format(fechaHora);
                              final estado = cita['estado'] ?? 'pendiente';
                              
                              Color estadoColor;
                              Color tituloColor;
                              Color fondo;
                              String estadoTexto;

                              switch (estado) {
                                case 'confirmada':
                                  estadoColor = const Color(0xFF2ECC71);
                                  tituloColor = const Color(0xFF2ECC71);
                                  fondo = const Color(0xFF0D2538);
                                  estadoTexto = 'Confirmada';
                                  break;
                                case 'completada':
                                  estadoColor = const Color(0xFF636976);
                                  tituloColor = const Color(0xFF9CA3AF);
                                  fondo = const Color(0xFF0B121F);
                                  estadoTexto = 'Finalizada';
                                  break;
                                case 'cancelada':
                                  estadoColor = AppTheme.errorRed;
                                  tituloColor = AppTheme.errorRed;
                                  fondo = const Color(0xFF2B0D0D);
                                  estadoTexto = 'Cancelada';
                                  break;
                                default:
                                  estadoColor = AppTheme.primaryOrange;
                                  tituloColor = AppTheme.primaryOrange;
                                  fondo = const Color(0xFF3B2612);
                                  estadoTexto = 'Pendiente';
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _TimelineCard(
                                  estadoColor: estadoColor,
                                  lineaColor: const Color(0xFF2C3344),
                                  fondo: fondo,
                                  titulo: '$horaFormato - $estadoTexto',
                                  tituloColor: tituloColor,
                                  servicio: cita['servicio_nombre'] ?? 'Servicio',
                                  cliente: cita['usuario_nombre'] ?? 'Cliente',
                                  esUltimo: esUltimo,
                                ),
                              );
                            }).toList(),

                          const SizedBox(height: 28),

                          // Promociones
                          Text(
                            'Promociones',
                            style: AppTheme.heading2.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SeccionGrandeCard(
                            color: const Color(0xFF3B2612),
                            icon: Icons.campaign_rounded,
                            titulo: 'Promociones',
                            descripcion: _promociones.isEmpty
                                ? 'No tienes promociones activas'
                                : '${_promociones.length} promoción${_promociones.length != 1 ? "es" : ""} activa${_promociones.length != 1 ? "s" : ""}',
                            botonTexto: '+ Añadir',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GestionarPromocionesPage(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // Recordatorios
                          _SeccionGrandeCard(
                            color: const Color(0xFF0D2538),
                            icon: Icons.check_circle_outline,
                            iconColor: const Color(0xFF74A9FF),
                            titulo: 'Recordatorios operativos',
                            descripcion: _citasPorConfirmar == 0
                                ? 'No hay citas pendientes'
                                : '$_citasPorConfirmar cita${_citasPorConfirmar != 1 ? "s" : ""} por confirmar',
                            botonTexto: 'Ver',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CalendarPage(mode: 'view'),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 28),

                          // Últimas reseñas
                          Text(
                            'Últimas reseñas',
                            style: AppTheme.heading2.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_resenas.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: AppTheme.cardDecoration(borderRadius: 20),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.rate_review_outlined,
                                      size: 48,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Aún no tienes reseñas',
                                      style: AppTheme.bodyLarge.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 150,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _resenas.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final resena = _resenas[index];
                                  final comentario = resena['comentario'] ?? '';
                                  final calificacion = (resena['calificacion'] ?? 0).toInt();
                                  final nombreUsuario = resena['usuario_nombre'] ?? 'Cliente';
                                  
                                  String fechaRelativa = 'Reciente';
                                  if (resena['created_at'] != null) {
                                    try {
                                      final fecha = DateTime.parse(resena['created_at']);
                                      final diferencia = DateTime.now().difference(fecha);
                                      
                                      if (diferencia.inDays > 7) {
                                        fechaRelativa = 'hace ${diferencia.inDays ~/ 7} semana${diferencia.inDays ~/ 7 != 1 ? "s" : ""}';
                                      } else if (diferencia.inDays > 0) {
                                        fechaRelativa = 'hace ${diferencia.inDays} día${diferencia.inDays != 1 ? "s" : ""}';
                                      } else if (diferencia.inHours > 0) {
                                        fechaRelativa = 'hace ${diferencia.inHours} hora${diferencia.inHours != 1 ? "s" : ""}';
                                      }
                                    } catch (e) {
                                      // Usar valor por defecto
                                    }
                                  }

                                  return _ResenaCard(
                                    texto: comentario.isNotEmpty ? '"$comentario"' : '"Buen servicio"',
                                    cliente: nombreUsuario,
                                    fecha: fechaRelativa,
                                    calificacion: calificacion,
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          border: Border(
            top: BorderSide(color: AppTheme.dividerColor),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _NavItem(
                icon: Icons.home,
                label: 'Inicio',
                selected: true,
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EstadisticasSalonPage(),
                    ),
                  );
                },
                child: const _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Estadísticas',
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GestionarPromocionesPage(),
                    ),
                  );
                },
                child: const _NavItem(
                  icon: Icons.local_offer_outlined,
                  label: 'Mis Promociones',
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalendarPage(),
                    ),
                  );
                },
                child: const _NavItem(
                  icon: Icons.calendar_today,
                  label: 'Calendario',
                ),
              ),
              GestureDetector(
                onTap: () {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileMenuPage(uid: uid),
                    ),
                  );
                },
                child: const _NavItem(
                  icon: Icons.person_outline,
                  label: 'Perfil',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------- Widgets de UI auxiliares -----------------

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primaryOrange : AppTheme.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.caption.copyWith(
            color: color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Color estadoColor;
  final Color lineaColor;
  final Color fondo;
  final String titulo;
  final Color tituloColor;
  final String servicio;
  final String cliente;
  final bool esUltimo;

  const _TimelineCard({
    Key? key,
    required this.estadoColor,
    required this.lineaColor,
    required this.fondo,
    required this.titulo,
    required this.tituloColor,
    required this.servicio,
    required this.cliente,
    this.esUltimo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Línea vertical + punto
        Column(
          children: [
            Container(
              width: 2,
              height: 18,
              color: lineaColor,
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: estadoColor,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: esUltimo ? 18 : 48,
              color: lineaColor,
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Card de información
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tituloColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  servicio,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cliente,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SeccionGrandeCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color? iconColor;
  final String titulo;
  final String descripcion;
  final String botonTexto;
  final VoidCallback onPressed;

  const _SeccionGrandeCard({
    Key? key,
    required this.color,
    required this.icon,
    this.iconColor,
    required this.titulo,
    required this.descripcion,
    required this.botonTexto,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color resolvedIconColor = iconColor ?? AppTheme.primaryOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: resolvedIconColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: resolvedIconColor,
              size: 22,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              backgroundColor: AppTheme.primaryOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              botonTexto,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResenaCard extends StatelessWidget {
  final String texto;
  final String cliente;
  final String fecha;
  final int calificacion;

  const _ResenaCard({
    Key? key,
    required this.texto,
    required this.cliente,
    required this.fecha,
    this.calificacion = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2538),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estrellitas dinámicas
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < calificacion ? Icons.star : Icons.star_border,
                size: 16,
                color: Colors.orangeAccent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            cliente,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fecha,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}