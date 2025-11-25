import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'theme/app_theme.dart';

class EstadisticasSalonPage extends StatefulWidget {
  const EstadisticasSalonPage({Key? key}) : super(key: key);

  @override
  State<EstadisticasSalonPage> createState() => _EstadisticasSalonPageState();
}

class _EstadisticasSalonPageState extends State<EstadisticasSalonPage> {
  bool _isLoading = true;
  int _citasHoy = 0;
  double _ingresosHoy = 0;
  int _citasProximos7Dias = 0;
  double _ingresosProximos7Dias = 0;
  List<Map<String, dynamic>> _proximosClientes = [];

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      // ✅ CAMBIO: Primero obtener el comercio_id del usuario salon
      print('🔍 Buscando comercio para uid: ${user.uid}');

      final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
      final comerciosResponse = await http.get(
        comerciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (comerciosResponse.statusCode != 200) {
        print('❌ Error obteniendo comercios: ${comerciosResponse.statusCode}');
        setState(() => _isLoading = false);
        return;
      }

      final List<dynamic> comercios = json.decode(comerciosResponse.body);

      // Buscar el comercio que pertenece a este usuario
      final miComercio = comercios.firstWhere(
        (c) => c['uid_negocio'] == user.uid,
        orElse: () => null,
      );

      if (miComercio == null) {
        print('⚠️ No se encontró comercio para este usuario');
        setState(() => _isLoading = false);
        return;
      }

      final comercioId = miComercio['id'];
      print('✅ Comercio encontrado: $comercioId');

      // ✅ CAMBIO: Obtener todas las citas del comercio (sin filtro de estado)
      final citasUrl = Uri.parse('$apiBaseUrl/citas?comercio_id=$comercioId');
      print('📍 Consultando citas: $citasUrl');

      final citasResponse = await http.get(
        citasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      print('📥 Status citas: ${citasResponse.statusCode}');

      if (citasResponse.statusCode == 200) {
        final List<dynamic> todasLasCitas = json.decode(citasResponse.body);
        print('📋 Total citas encontradas: ${todasLasCitas.length}');

        if (todasLasCitas.isNotEmpty) {
          print('📄 Ejemplo de cita: ${todasLasCitas[0]}');
        }

        final ahora = DateTime.now();
        final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day);
        final hoyFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
        final fecha7Dias = hoyInicio.add(const Duration(days: 7));

        int citasHoy = 0;
        double ingresosHoy = 0;
        int citas7Dias = 0;
        double ingresos7Dias = 0;
        List<Map<String, dynamic>> proximosList = [];
        final manana = hoyInicio.add(const Duration(days: 1));

        for (var cita in todasLasCitas) {
          try {
            // ✅ CAMBIO: Parsear fecha correctamente
            DateTime fechaCita;
            final fechaHoraStr = cita['fecha_hora'];

            if (fechaHoraStr is String) {
              // Si es string tipo "2024-11-14T10:00" o "2024-11-14T10:00:00"
              fechaCita = DateTime.parse(fechaHoraStr);
            } else if (fechaHoraStr is Map &&
                fechaHoraStr.containsKey('_seconds')) {
              // Si es un Timestamp de Firestore serializado
              final seconds = fechaHoraStr['_seconds'] as int;
              fechaCita = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            } else {
              print('⚠️ Formato de fecha no reconocido: $fechaHoraStr');
              continue;
            }

            print('📅 Cita: ${cita['id']} - Fecha: $fechaCita');

            // ✅ Citas de hoy
            if (fechaCita.isAfter(hoyInicio) && fechaCita.isBefore(hoyFin)) {
              citasHoy++;
              ingresosHoy += (cita['precio'] ?? 0).toDouble();
              print('   ✅ Es de hoy');
            }
            // ✅ Citas próximos 7 días (desde mañana)
            if (fechaCita.isAfter(manana) && fechaCita.isBefore(fecha7Dias)) {
              citas7Dias++;
              ingresos7Dias += (cita['precio'] ?? 0).toDouble();
              print('   ✅ Está en próximos 7 días');
            }

            // ✅ Citas futuras para lista de próximos clientes
            if (fechaCita.isAfter(ahora)) {
              proximosList.add({
                ...cita,
                'fecha_hora_parsed': fechaCita,
              });
            }
          } catch (e) {
            print('❌ Error procesando cita ${cita['id']}: $e');
          }
        }

        // Ordenar próximos clientes por fecha
        proximosList.sort((a, b) {
          final fechaA = a['fecha_hora_parsed'] as DateTime;
          final fechaB = b['fecha_hora_parsed'] as DateTime;
          return fechaA.compareTo(fechaB);
        });

        setState(() {
          _citasHoy = citasHoy;
          _ingresosHoy = ingresosHoy;
          _citasProximos7Dias = citas7Dias;
          _ingresosProximos7Dias = ingresos7Dias;
          _proximosClientes =
              proximosList.take(3).map((c) => c as Map<String, dynamic>? ?? {}).toList();
          _isLoading = false;
        });

        print('✅ Estadísticas calculadas:');
        print('   📅 Hoy ($hoyInicio - $hoyFin):');
        print('      Citas: $citasHoy');
        print('      Ingresos: L${ingresosHoy.toStringAsFixed(2)}');
        print('   📅 Próximos 7 días ($manana - $fecha7Dias):');
        print('      Citas: $citas7Dias');
        print('      Ingresos: L${ingresos7Dias.toStringAsFixed(2)}');
      } else {
        print('Error HTTP: ${citasResponse.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      print('Error cargando estadísticas: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  TextStyle get _sectionTitleStyle => const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Resumen de rendimiento del salón',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryOrange,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MÉTRICAS DE HOY
                  const SizedBox(height: 8),
                  Text('Métricas de HOY', style: _sectionTitleStyle),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TodayMetricCard(
                          titulo: 'Citas de hoy',
                          valor: '$_citasHoy',
                          variacionTexto: '+5%',
                          variacionColor: const Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TodayMetricCard(
                          titulo: 'Ingresos de hoy',
                          valor: 'L${_ingresosHoy.toStringAsFixed(0)}',
                          variacionTexto: '+5%',
                          variacionColor: const Color(0xFF22C55E),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // PRÓXIMOS 7 DÍAS
                  Text('Próximos 7 días', style: _sectionTitleStyle),
                  const SizedBox(height: 12),
                  _WideMetricCard(
                    titulo: 'Citas',
                    valor: '$_citasProximos7Dias',
                    detalle: '7 días • +10%',
                    icon: Icons.calendar_today_outlined,
                  ),
                  const SizedBox(height: 12),
                  _WideMetricCard(
                    titulo: 'Ingresos',
                    valor: 'L${_ingresosProximos7Dias.toStringAsFixed(0)}',
                    detalle: '7 días • +8%',
                    icon: Icons.attach_money_rounded,
                  ),

                  const SizedBox(height: 28),

                  // RENDIMIENTO SEMANAL DETALLADO (dummy visual)
                  Text(
                    'Rendimiento Semanal Detallado',
                    style: _sectionTitleStyle,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Expanded(
                        child: _MiniMetricCard(
                          titulo: 'Prom. Citas / Día',
                          valor: '15',
                          detalle: '+2 vs. sem. anterior',
                          detalleColor: Color(0xFF22C55E),
                          icon: Icons.trending_up,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _MiniMetricCard(
                          titulo: 'Prom. Ingresos / Día',
                          valor: 'L750',
                          detalle: '-L50 vs. sem. anterior',
                          detalleColor: Color(0xFFEF4444),
                          icon: Icons.trending_down,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // SERVICIOS TOP
                  Text(
                    'Servicios Top (Top 3)',
                    style: _sectionTitleStyle,
                  ),
                  const SizedBox(height: 12),
                  const _ServiciosTopCard(),

                  const SizedBox(height: 28),

                  // NUEVOS CLIENTES Y ESTRELLAS (dummy visual)
                  Row(
                    children: const [
                      Expanded(
                        child: _MiniMetricCard(
                          titulo: 'Nuevos clientes',
                          valor: '25',
                          detalle: '+15% este mes',
                          detalleColor: Color(0xFF22C55E),
                          icon: Icons.person_add_alt_1_rounded,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _MiniMetricCard(
                          titulo: 'Estrellas',
                          valor: '4.8/5',
                          detalle: '125 reseñas',
                          detalleColor: Color(0xFF9CA3AF),
                          icon: Icons.star_rounded,
                          iconColor: Color(0xFFFACC15),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // PRÓXIMOS CLIENTES (usa la lógica ya calculada)
                  if (_proximosClientes.isNotEmpty) ...[
                    Text(
                      'Próximas citas',
                      style: _sectionTitleStyle,
                    ),
                    const SizedBox(height: 12),
                    ..._proximosClientes.map(
                      (cita) => _ProximoClienteTile(cita: cita),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // PROMOCIONES MÁS EFECTIVAS (dummy visual)
                  Text(
                    'Promociones más efectivas',
                    style: _sectionTitleStyle,
                  ),
                  const SizedBox(height: 12),
                  const _PromoEfectivaCard(),
                ],
              ),
            ),
    );
  }
}

// ---------------- WIDGETS DE UI ----------------

class _TodayMetricCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String variacionTexto;
  final Color variacionColor;

  const _TodayMetricCard({
    Key? key,
    required this.titulo,
    required this.valor,
    required this.variacionTexto,
    required this.variacionColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            variacionTexto,
            style: TextStyle(
              color: variacionColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WideMetricCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String detalle;
  final IconData icon;

  const _WideMetricCard({
    Key? key,
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  valor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detalle,
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryOrange,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String detalle;
  final Color detalleColor;
  final IconData icon;
  final Color? iconColor;

  const _MiniMetricCard({
    Key? key,
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.detalleColor,
    required this.icon,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color resolvedIconColor = iconColor ?? AppTheme.primaryOrange;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: resolvedIconColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: resolvedIconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detalle,
            style: TextStyle(
              color: detalleColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiciosTopCard extends StatelessWidget {
  const _ServiciosTopCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ServicioBar(
            nombre: 'Corte y Peinado',
            porcentaje: 0.45,
            porcentajeTexto: '45%',
          ),
          SizedBox(height: 10),
          _ServicioBar(
            nombre: 'Coloración',
            porcentaje: 0.30,
            porcentajeTexto: '30%',
            colorBar: Color(0xFF3B82F6),
          ),
          SizedBox(height: 10),
          _ServicioBar(
            nombre: 'Manicura',
            porcentaje: 0.25,
            porcentajeTexto: '25%',
          ),
        ],
      ),
    );
  }
}

class _ServicioBar extends StatelessWidget {
  final String nombre;
  final double porcentaje;
  final String porcentajeTexto;
  final Color? colorBar;

  const _ServicioBar({
    Key? key,
    required this.nombre,
    required this.porcentaje,
    required this.porcentajeTexto,
    this.colorBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color barColor = colorBar ?? AppTheme.primaryOrange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              porcentajeTexto,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: porcentaje,
            minHeight: 8,
            backgroundColor: const Color(0xFF1F2933),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

class _PromoEfectivaCard extends StatelessWidget {
  const _PromoEfectivaCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Pack Relajación Total',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Masaje + Facial',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text(
                '28%',
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'de uso',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProximoClienteTile extends StatelessWidget {
  final Map<String, dynamic> cita;

  const _ProximoClienteTile({Key? key, required this.cita}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fecha = cita['fecha_hora_parsed'] as DateTime?;
    final horaTexto =
        fecha != null ? '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}' : '';

    final precio = (cita['precio'] ?? 0).toDouble();
    final servicio = cita['servicio_nombre'] ?? 'Servicio';
    final cliente = cita['nombre_cliente'] ?? 'Cliente';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppTheme.primaryOrange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servicio,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cliente,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                horaTexto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'L${precio.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}