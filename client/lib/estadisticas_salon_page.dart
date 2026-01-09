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
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

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

      // Llamar al nuevo endpoint de estadísticas que retorna todo calculado
      final estadisticasUrl = Uri.parse('$apiBaseUrl/api/estadisticas/salon/$comercioId');
      final estadisticasResponse = await http.get(
        estadisticasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (estadisticasResponse.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(estadisticasResponse.body);
        
        setState(() {
          _citasHoy = data['citasHoy'] ?? 0;
          _ingresosHoy = (data['ingresosHoy'] ?? 0).toDouble();
          _citasProximos7Dias = data['citasProximos7Dias'] ?? 0;
          _ingresosProximos7Dias = (data['ingresosProximos7Dias'] ?? 0).toDouble();
          _proximosClientes = List<Map<String, dynamic>>.from(data['proximosClientes'] ?? []);
          _promCitasPorDia = (data['promCitasPorDia'] ?? 0).toDouble();
          _difCitasVsSemanaAnterior = data['difCitasVsSemanaAnterior'] ?? 0;
          _promIngresosPorDia = (data['promIngresosPorDia'] ?? 0).toDouble();
          _difIngresosVsSemanaAnterior = (data['difIngresosVsSemanaAnterior'] ?? 0).toDouble();
          _serviciosTop = List<Map<String, dynamic>>.from(data['serviciosTop'] ?? []);
          _nuevosClientes = data['nuevosClientes'] ?? 0;
          _calificacionPromedio = (data['calificacionPromedio'] ?? 0).toDouble();
          _totalResenas = data['totalResenas'] ?? 0;
          _promocionesEfectivas = List<Map<String, dynamic>>.from(data['promocionesEfectivas'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
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
              porcentaje: (servicios[i]['porcentaje'] as num? ?? 0).toDouble() / 100,
              solicitudes: servicios[i]['solicitudes'] ?? 0,
              porcentajeTexto: '${servicios[i]['porcentaje'] ?? 0}%',
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
  final int solicitudes;
  final String porcentajeTexto;
  final Color? colorBar;

  const _ServicioBar({
    Key? key,
    required this.nombre,
    required this.porcentaje,
    required this.solicitudes,
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