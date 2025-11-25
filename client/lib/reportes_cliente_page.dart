import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'theme/app_theme.dart';

class ReportesClientePage extends StatefulWidget {
  const ReportesClientePage({Key? key}) : super(key: key);

  @override
  State<ReportesClientePage> createState() => _ReportesClientePageState();
}

class _ReportesClientePageState extends State<ReportesClientePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _citas = [];
  List<Map<String, dynamic>> _pagos = [];
  
  double _gastoTotal = 0;
  double _gastoMesActual = 0;
  double _gastoMesAnterior = 0;
  int _totalCitas = 0;
  int _citasCompletadas = 0;
  
  Map<String, double> _gastosPorServicio = {};
  Map<String, int> _frecuenciaPorServicio = {};
  Map<String, double> _gastosPorSalon = {};
  Map<String, int> _frecuenciaPorSalon = {};
  
  String? _servicioFavorito;
  String? _salonFavorito;
  
  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final uid = user.uid;
      final idToken = await user.getIdToken();

      // Cargar citas del usuario
      final citasUrl = Uri.parse('$apiBaseUrl/citas/usuario/$uid');
      print('🔍 Cargando citas: $citasUrl');

      final citasResponse = await http.get(
        citasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 8));

      if (citasResponse.statusCode == 200) {
        final List<dynamic> citasData = json.decode(citasResponse.body);
        _citas = citasData.cast<Map<String, dynamic>>();
        print('✅ ${_citas.length} citas cargadas');
      }

      // Cargar pagos del usuario
      final pagosUrl = Uri.parse('$apiBaseUrl/api/pagos?usuario_id=$uid');
      print('🔍 Cargando pagos: $pagosUrl');

      final pagosResponse = await http.get(
        pagosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 8));

      if (pagosResponse.statusCode == 200) {
        final List<dynamic> pagosData = json.decode(pagosResponse.body);
        _pagos = pagosData.cast<Map<String, dynamic>>();
        print('✅ ${_pagos.length} pagos cargados');
      }

      _procesarEstadisticas();

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error cargando datos: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _procesarEstadisticas() {
    final now = DateTime.now();
    final inicioMesActual = DateTime(now.year, now.month, 1);
    final inicioMesAnterior = DateTime(now.year, now.month - 1, 1);
    final finMesAnterior = DateTime(now.year, now.month, 0, 23, 59, 59);

    _totalCitas = _citas.length;
    _citasCompletadas = _citas.where((c) => c['estado'] == 'completada').length;

    // Calcular gastos
    for (var pago in _pagos) {
      final monto = (pago['monto'] ?? 0).toDouble();
      final servicio = pago['servicio_nombre'] ?? 'Servicio';
      final salon = pago['comercio_nombre'] ?? 'Salón';
      
      _gastoTotal += monto;

      // Acumular por servicio
      _gastosPorServicio[servicio] = (_gastosPorServicio[servicio] ?? 0) + monto;
      _frecuenciaPorServicio[servicio] = (_frecuenciaPorServicio[servicio] ?? 0) + 1;

      // Acumular por salón
      _gastosPorSalon[salon] = (_gastosPorSalon[salon] ?? 0) + monto;
      _frecuenciaPorSalon[salon] = (_frecuenciaPorSalon[salon] ?? 0) + 1;

      // Calcular por mes
      if (pago['created_at'] != null) {
        try {
          final fecha = DateTime.parse(pago['created_at']);
          if (fecha.isAfter(inicioMesActual)) {
            _gastoMesActual += monto;
          } else if (fecha.isAfter(inicioMesAnterior) && fecha.isBefore(finMesAnterior)) {
            _gastoMesAnterior += monto;
          }
        } catch (e) {
          print('Error parseando fecha: $e');
        }
      }
    }

    // Encontrar favoritos
    if (_frecuenciaPorServicio.isNotEmpty) {
      _servicioFavorito = _frecuenciaPorServicio.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    if (_frecuenciaPorSalon.isNotEmpty) {
      _salonFavorito = _frecuenciaPorSalon.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
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
        title: Text('Mis Reportes', style: AppTheme.heading3),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📊 Resumen general
                  Text(
                    'Resumen General',
                    style: AppTheme.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cards de resumen
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Gasto Total',
                          'L ${_gastoTotal.toStringAsFixed(2)}',
                          Icons.account_balance_wallet_outlined,
                          AppTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Citas Totales',
                          '$_totalCitas',
                          Icons.event_outlined,
                          const Color(0xFF2ECC71),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Mes Actual',
                          'L ${_gastoMesActual.toStringAsFixed(2)}',
                          Icons.calendar_month,
                          const Color(0xFF74A9FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Completadas',
                          '$_citasCompletadas',
                          Icons.check_circle_outline,
                          const Color(0xFF9B59B6),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 📈 Comparativa mensual
                  Text(
                    'Comparativa Mensual',
                    style: AppTheme.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildComparativaCard(),

                  const SizedBox(height: 32),

                  // ⭐ Favoritos
                  Text(
                    'Tus Favoritos',
                    style: AppTheme.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_servicioFavorito != null)
                    _buildFavoritoCard(
                      'Servicio más usado',
                      _servicioFavorito!,
                      '${_frecuenciaPorServicio[_servicioFavorito]} veces',
                      Icons.cut,
                      const Color(0xFF3B2612),
                    ),
                  const SizedBox(height: 12),
                  if (_salonFavorito != null)
                    _buildFavoritoCard(
                      'Salón favorito',
                      _salonFavorito!,
                      '${_frecuenciaPorSalon[_salonFavorito]} visitas',
                      Icons.store,
                      const Color(0xFF0D2538),
                    ),

                  const SizedBox(height: 32),

                  // 💰 Top 5 servicios por gasto
                  Text(
                    'Top 5 Servicios por Gasto',
                    style: AppTheme.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTopServiciosGasto(),

                  const SizedBox(height: 32),

                  // 🏆 Top 5 salones por frecuencia
                  Text(
                    'Top 5 Salones Más Visitados',
                    style: AppTheme.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTopSalonesFrecuencia(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            valor,
            style: AppTheme.heading2.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparativaCard() {
    final diferencia = _gastoMesActual - _gastoMesAnterior;
    final porcentaje = _gastoMesAnterior > 0
        ? ((diferencia / _gastoMesAnterior) * 100)
        : 0.0;
    final esPositivo = diferencia > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mes Actual',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'L ${_gastoMesActual.toStringAsFixed(2)}',
                    style: AppTheme.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Mes Anterior',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'L ${_gastoMesAnterior.toStringAsFixed(2)}',
                    style: AppTheme.heading3.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: esPositivo
                  ? AppTheme.errorRed.withOpacity(0.15)
                  : const Color(0xFF2ECC71).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  esPositivo ? Icons.trending_up : Icons.trending_down,
                  color: esPositivo ? AppTheme.errorRed : const Color(0xFF2ECC71),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${esPositivo ? "+" : ""}${porcentaje.toStringAsFixed(1)}% vs mes anterior',
                  style: AppTheme.bodyMedium.copyWith(
                    color: esPositivo ? AppTheme.errorRed : const Color(0xFF2ECC71),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritoCard(String titulo, String nombre, String detalle, IconData icon, Color fondo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryOrange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nombre,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary, size: 16),
        ],
      ),
    );
  }

  Widget _buildTopServiciosGasto() {
    final topServicios = _gastosPorServicio.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top5 = topServicios.take(5).toList();

    if (top5.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.cardDecoration(borderRadius: 20),
        child: Center(
          child: Text(
            'Aún no tienes servicios registrados',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    final maxGasto = top5.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(borderRadius: 20),
      child: Column(
        children: top5.asMap().entries.map((entry) {
          final index = entry.key;
          final servicio = entry.value;
          final porcentaje = (servicio.value / maxGasto);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: index == 0
                            ? AppTheme.primaryGradient
                            : null,
                        color: index == 0 ? null : AppTheme.textSecondary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: index == 0 ? Colors.white : AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        servicio.key,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'L ${servicio.value.toStringAsFixed(2)}',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: porcentaje,
                    minHeight: 8,
                    backgroundColor: AppTheme.textSecondary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      index == 0 ? AppTheme.primaryOrange : AppTheme.primaryOrange.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopSalonesFrecuencia() {
    final topSalones = _frecuenciaPorSalon.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top5 = topSalones.take(5).toList();

    if (top5.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.cardDecoration(borderRadius: 20),
        child: Center(
          child: Text(
            'Aún no has visitado ningún salón',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(borderRadius: 20),
      child: Column(
        children: top5.asMap().entries.map((entry) {
          final index = entry.key;
          final salon = entry.value;
          final gasto = _gastosPorSalon[salon.key] ?? 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: index == 0 ? AppTheme.primaryGradient : null,
                    color: index == 0 ? null : AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.store,
                      color: index == 0 ? Colors.white : AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salon.key,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${salon.value} visitas • L ${gasto.toStringAsFixed(2)}',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
