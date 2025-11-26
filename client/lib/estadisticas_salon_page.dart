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
  
  // Nuevas estadísticas reales
  double _promCitasPorDia = 0;
  int _difCitasVsSemanaAnterior = 0;
  double _promIngresosPorDia = 0;
  double _difIngresosVsSemanaAnterior = 0;
  List<Map<String, dynamic>> _serviciosTop = [];
  int _nuevosClientes = 0;
  double _calificacionPromedio = 0;
  int _totalResenas = 0;
  List<Map<String, dynamic>> _promocionesEfectivas = [];

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken() ?? '';

      // Obtener comercio_id
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

      final comercioId = (miComercio['id'] ?? '').toString();
      if (comercioId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Cargar datos en paralelo
      await Future.wait([
        _cargarCitas(comercioId, idToken),
        _cargarServicios(comercioId, idToken),
        _cargarResenas(comercioId, idToken),
        _cargarPromociones(comercioId, idToken),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error cargando estadísticas: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarCitas(String comercioId, String idToken) async {
    try {
      final citasUrl = Uri.parse('$apiBaseUrl/citas?comercio_id=$comercioId');
      final citasResponse = await http.get(
        citasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (citasResponse.statusCode != 200) return;

      final List<dynamic> todasLasCitas = json.decode(citasResponse.body);
      
      final ahora = DateTime.now();
      final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day);
      final hoyFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
      final manana = hoyInicio.add(const Duration(days: 1));
      final fecha7Dias = hoyInicio.add(const Duration(days: 7));
      final inicioSemanaActual = hoyInicio.subtract(Duration(days: 7));
      final inicioSemanaAnterior = inicioSemanaActual.subtract(const Duration(days: 7));
      final inicioMes = DateTime(ahora.year, ahora.month, 1);

      int citasHoy = 0;
      double ingresosHoy = 0;
      int citas7Dias = 0;
      double ingresos7Dias = 0;
      int citasSemanaActual = 0;
      double ingresosSemanaActual = 0;
      int citasSemanaAnterior = 0;
      double ingresosSemanaAnterior = 0;
      Set<String> clientesUnicos = {};
      List<Map<String, dynamic>> proximosList = [];
      Map<String, int> serviciosCount = {};

      for (var cita in todasLasCitas) {
        try {
          DateTime fechaCita;
          final fechaHoraStr = cita['fecha_hora'];

          if (fechaHoraStr is String) {
            fechaCita = DateTime.parse(fechaHoraStr);
          } else if (fechaHoraStr is Map && fechaHoraStr.containsKey('_seconds')) {
            final seconds = fechaHoraStr['_seconds'] as int;
            fechaCita = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          } else {
            continue;
          }

          final precio = (cita['precio'] ?? 0).toDouble();
          final servicioId = cita['servicio_id']?.toString() ?? '';
          final clienteId = cita['usuario_id']?.toString() ?? '';

          // Citas de hoy
          if (fechaCita.isAfter(hoyInicio) && fechaCita.isBefore(hoyFin)) {
            citasHoy++;
            ingresosHoy += precio;
          }

          // Citas próximos 7 días
          if (fechaCita.isAfter(manana) && fechaCita.isBefore(fecha7Dias)) {
            citas7Dias++;
            ingresos7Dias += precio;
          }

          // Citas semana actual (últimos 7 días)
          if (fechaCita.isAfter(inicioSemanaActual) && fechaCita.isBefore(ahora)) {
            citasSemanaActual++;
            ingresosSemanaActual += precio;
          }

          // Citas semana anterior (7-14 días atrás)
          if (fechaCita.isAfter(inicioSemanaAnterior) && fechaCita.isBefore(inicioSemanaActual)) {
            citasSemanaAnterior++;
            ingresosSemanaAnterior += precio;
          }

          // Nuevos clientes este mes
          if (fechaCita.isAfter(inicioMes) && clienteId.isNotEmpty) {
            clientesUnicos.add(clienteId);
          }

          // Contar servicios más solicitados
          if (servicioId.isNotEmpty) {
            serviciosCount[servicioId] = (serviciosCount[servicioId] ?? 0) + 1;
          }

          // Próximas citas
          if (fechaCita.isAfter(ahora)) {
            proximosList.add({
              ...cita,
              'fecha_hora_parsed': fechaCita,
            });
          }
        } catch (e) {
          print('Error procesando cita: $e');
        }
      }

      proximosList.sort((a, b) {
        final fechaA = a['fecha_hora_parsed'] as DateTime;
        final fechaB = b['fecha_hora_parsed'] as DateTime;
        return fechaA.compareTo(fechaB);
      });

      // Calcular promedios y diferencias
      final promCitasSemanaActual = citasSemanaActual / 7;
      final promCitasSemanaAnterior = citasSemanaAnterior > 0 ? citasSemanaAnterior / 7 : 0;
      final difCitas = (promCitasSemanaActual - promCitasSemanaAnterior).round();

      final promIngresosSemanaActual = ingresosSemanaActual / 7;
      final promIngresosSemanaAnterior = ingresosSemanaAnterior > 0 ? ingresosSemanaAnterior / 7 : 0;
      final difIngresos = promIngresosSemanaActual - promIngresosSemanaAnterior;

      setState(() {
        _citasHoy = citasHoy;
        _ingresosHoy = ingresosHoy;
        _citasProximos7Dias = citas7Dias;
        _ingresosProximos7Dias = ingresos7Dias;
        _proximosClientes = proximosList.take(3).toList();
        _promCitasPorDia = promCitasSemanaActual;
        _difCitasVsSemanaAnterior = difCitas;
        _promIngresosPorDia = promIngresosSemanaActual;
        _difIngresosVsSemanaAnterior = difIngresos;
        _nuevosClientes = clientesUnicos.length;
      });

      // Guardar servicios count para usarlo después
      _serviciosCountTemp = serviciosCount;
    } catch (e) {
      print('Error cargando citas: $e');
    }
  }

  Map<String, int> _serviciosCountTemp = {};

  Future<void> _cargarServicios(String comercioId, String idToken) async {
    try {
      final serviciosUrl = Uri.parse('$apiBaseUrl/servicios?comercio_id=$comercioId');
      final serviciosResponse = await http.get(
        serviciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (serviciosResponse.statusCode != 200) return;

      final List<dynamic> servicios = json.decode(serviciosResponse.body);
      
      // Combinar servicios con su conteo
      List<Map<String, dynamic>> serviciosConConteo = [];
      int totalCitas = _serviciosCountTemp.values.fold(0, (sum, count) => sum + count);

      for (var servicio in servicios) {
        final servicioId = servicio['id']?.toString() ?? '';
        final count = _serviciosCountTemp[servicioId] ?? 0;
        
        if (count > 0 && totalCitas > 0) {
          serviciosConConteo.add({
            'nombre': servicio['nombre'] ?? 'Servicio',
            'count': count,
            'porcentaje': (count / totalCitas),
          });
        }
      }

      // Ordenar por count descendente y tomar top 3
      serviciosConConteo.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      setState(() {
        _serviciosTop = serviciosConConteo.take(3).toList();
      });
    } catch (e) {
      print('Error cargando servicios: $e');
    }
  }

  Future<void> _cargarResenas(String comercioId, String idToken) async {
    try {
      final resenasUrl = Uri.parse('$apiBaseUrl/api/resenas?comercio_id=$comercioId');
      final resenasResponse = await http.get(
        resenasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (resenasResponse.statusCode != 200) return;

      final List<dynamic> resenas = json.decode(resenasResponse.body);
      
      if (resenas.isEmpty) {
        setState(() {
          _calificacionPromedio = 0;
          _totalResenas = 0;
        });
        return;
      }

      double sumaCalificaciones = 0;
      for (var resena in resenas) {
        sumaCalificaciones += (resena['calificacion'] ?? 0).toDouble();
      }

      setState(() {
        _calificacionPromedio = sumaCalificaciones / resenas.length;
        _totalResenas = resenas.length;
      });
    } catch (e) {
      print('Error cargando reseñas: $e');
    }
  }

  Future<void> _cargarPromociones(String comercioId, String idToken) async {
    try {
      final promocionesUrl = Uri.parse('$apiBaseUrl/api/promociones/comercio/$comercioId');
      final promocionesResponse = await http.get(
        promocionesUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (promocionesResponse.statusCode != 200) return;

      final List<dynamic> promociones = json.decode(promocionesResponse.body);
      
      // Ordenar por usos (campo ficticio por ahora) y tomar top 1
      List<Map<String, dynamic>> promocionesConUso = [];
      for (var promo in promociones) {
        promocionesConUso.add({
          'titulo': promo['titulo'] ?? 'Promoción',
          'descripcion': promo['descripcion'] ?? '',
          'usos': 0, // TODO: implementar conteo real cuando exista la tabla de uso de promociones
        });
      }

      setState(() {
        _promocionesEfectivas = promocionesConUso.take(1).toList();
      });
    } catch (e) {
      print('Error cargando promociones: $e');
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

                  // RENDIMIENTO SEMANAL DETALLADO
                  Text(
                    'Rendimiento Semanal Detallado',
                    style: _sectionTitleStyle,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniMetricCard(
                          titulo: 'Prom. Citas / Día',
                          valor: _promCitasPorDia.toStringAsFixed(1),
                          detalle: _difCitasVsSemanaAnterior >= 0
                              ? '+${_difCitasVsSemanaAnterior} vs. sem. anterior'
                              : '${_difCitasVsSemanaAnterior} vs. sem. anterior',
                          detalleColor: _difCitasVsSemanaAnterior >= 0
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444),
                          icon: _difCitasVsSemanaAnterior >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniMetricCard(
                          titulo: 'Prom. Ingresos / Día',
                          valor: 'L${_promIngresosPorDia.toStringAsFixed(0)}',
                          detalle: _difIngresosVsSemanaAnterior >= 0
                              ? '+L${_difIngresosVsSemanaAnterior.toStringAsFixed(0)} vs. sem. anterior'
                              : '-L${(-_difIngresosVsSemanaAnterior).toStringAsFixed(0)} vs. sem. anterior',
                          detalleColor: _difIngresosVsSemanaAnterior >= 0
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444),
                          icon: _difIngresosVsSemanaAnterior >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
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
                  _serviciosTop.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            'No hay datos de servicios aún',
                            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                          ),
                        )
                      : _ServiciosTopCard(servicios: _serviciosTop),

                  const SizedBox(height: 28),

                  // NUEVOS CLIENTES Y ESTRELLAS
                  Row(
                    children: [
                      Expanded(
                        child: _MiniMetricCard(
                          titulo: 'Nuevos clientes',
                          valor: '$_nuevosClientes',
                          detalle: 'este mes',
                          detalleColor: const Color(0xFF9CA3AF),
                          icon: Icons.person_add_alt_1_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniMetricCard(
                          titulo: 'Estrellas',
                          valor: _totalResenas > 0
                              ? '${_calificacionPromedio.toStringAsFixed(1)}/5'
                              : 'N/A',
                          detalle: _totalResenas > 0
                              ? '$_totalResenas reseñas'
                              : 'Sin reseñas',
                          detalleColor: const Color(0xFF9CA3AF),
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFFACC15),
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

                  // PROMOCIONES MÁS EFECTIVAS
                  if (_promocionesEfectivas.isNotEmpty) ...[
                    Text(
                      'Promociones más efectivas',
                      style: _sectionTitleStyle,
                    ),
                    const SizedBox(height: 12),
                    _PromoEfectivaCard(promo: _promocionesEfectivas[0]),
                  ],
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
  final List<Map<String, dynamic>> servicios;

  const _ServiciosTopCard({Key? key, required this.servicios}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppTheme.primaryOrange,
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < servicios.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ServicioBar(
              nombre: servicios[i]['nombre'] ?? 'Servicio',
              porcentaje: (servicios[i]['porcentaje'] as double?) ?? 0,
              porcentajeTexto: '${((servicios[i]['porcentaje'] as double? ?? 0) * 100).toStringAsFixed(0)}%',
              colorBar: colors[i % colors.length],
            ),
          ],
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
  final Map<String, dynamic> promo;

  const _PromoEfectivaCard({Key? key, required this.promo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final titulo = promo['titulo'] ?? 'Promoción';
    final descripcion = promo['descripcion'] ?? '';
    final usos = promo['usos'] ?? 0;

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
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                usos > 0 ? '$usos' : 'N/A',
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                usos > 0 ? 'usos' : 'sin datos',
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