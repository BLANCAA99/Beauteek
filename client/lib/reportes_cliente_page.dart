import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'api_constants.dart';
import 'theme/app_theme.dart';

class ReportesClientePage extends StatefulWidget {
  const ReportesClientePage({Key? key}) : super(key: key);

  @override
  State<ReportesClientePage> createState() => _ReportesClientePageState();
}

class _ReportesClientePageState extends State<ReportesClientePage> {
  bool _isLoading = false;
  String? _clienteId;
  String? _nombreCliente;
  String _periodoSeleccionado = 'Todos';
  Map<String, dynamic>? _datosReporte;
  Map<String, dynamic>? _datosGastosPorSalon;

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

      _clienteId = user.uid;
      _nombreCliente = user.displayName ?? 'Cliente';

      // Cargar reportes
      await _cargarReporte();
      await _cargarGastosPorSalon();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error cargando datos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarReporte() async {
    if (_clienteId == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final reporteUrl = Uri.parse(
        '$apiBaseUrl/api/reportes/cliente/$_clienteId?periodo=$_periodoSeleccionado',
      );

      print('🔍 Llamando a: $reporteUrl');

      final response = await http.get(
        reporteUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      print('📊 Status: ${response.statusCode}');
      print('📊 Body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _datosReporte = json.decode(response.body) as Map<String, dynamic>;
          print('✅ Datos cargados: $_datosReporte');
        });
      } else {
        print('❌ Error en respuesta: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar datos: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error cargando reporte: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cambiarPeriodo(String periodo) async {
    setState(() {
      _periodoSeleccionado = periodo;
      _isLoading = true;
    });
    await _cargarReporte();
    await _cargarGastosPorSalon();
    setState(() => _isLoading = false);
  }

  Future<void> _cargarGastosPorSalon() async {
    if (_clienteId == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse(
        '$apiBaseUrl/api/reportes/cliente/$_clienteId/gastos-por-salon',
      );

      print('🔍 Cargando gastos por salón: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _datosGastosPorSalon = json.decode(response.body) as Map<String, dynamic>;
          print('✅ Gastos por salón cargados: $_datosGastosPorSalon');
        });
      }
    } catch (e) {
      print('❌ Error cargando gastos por salón: $e');
    }
  }

  String _formatearMoneda(num cantidad) {
    return NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(cantidad.toDouble());
  }

  Future<void> _descargarResumenGeneral() async {
    if (_datosReporte == null) return;

    try {
      setState(() => _isLoading = true);

      final pdf = pw.Document();
      final gastoTotal = _datosReporte!['gastoTotal'] ?? 0.0;
      final totalCitas = _datosReporte!['totalCitas'] ?? 0;
      final citasCompletadas = _datosReporte!['citasCompletadas'] ?? 0;
      final citasCanceladas = _datosReporte!['citasCanceladas'] ?? 0;
      final salonesVisitados = _datosReporte!['salonesVisitados'] ?? 0;
      final serviciosFrecuentes = _datosReporte!['serviciosFrecuentes'] as List? ?? [];
      final salones = _datosReporte!['salones'] as List? ?? [];

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Mi Resumen General', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('$_nombreCliente - Periodo: $_periodoSeleccionado', style: pw.TextStyle(fontSize: 12)),
              pw.Divider(),
              pw.SizedBox(height: 20),
              
              // Estadísticas principales
              pw.Text('ESTADISTICAS GENERALES', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Gasto Total: ${_formatearMoneda(gastoTotal)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Total de Citas: $totalCitas'),
              pw.Text('Citas Completadas: $citasCompletadas'),
              pw.Text('Citas Canceladas: $citasCanceladas'),
              pw.Text('Salones Visitados: $salonesVisitados'),
              
              pw.SizedBox(height: 20),
              pw.Divider(),
              
              // Salones más visitados
              if (salones.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text('SALONES MAS VISITADOS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                ...salones.take(3).map((salon) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('${salon['nombre']} - ${salon['visitas']} visitas - ${_formatearMoneda(salon['gasto_total'])}'),
                )).toList(),
              ],
              
              pw.SizedBox(height: 15),
              pw.Divider(),
              
              // Servicios frecuentes
              if (serviciosFrecuentes.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text('SERVICIOS MAS FRECUENTES', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                ...serviciosFrecuentes.map((servicio) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('${servicio['nombre']} (${servicio['cantidad']} veces)'),
                )).toList(),
              ],
            ],
          ),
        ),
      );

      await _compartirPDF(pdf, 'mi_resumen_general');
    } catch (e) {
      print('Error: $e');
      _mostrarError('Error al generar el reporte');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarReporteSalones() async {
    if (_datosReporte == null) return;

    try {
      setState(() => _isLoading = true);

      final pdf = pw.Document();
      final salones = _datosReporte!['salones'] as List? ?? [];

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Mis Salones Visitados', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('$_nombreCliente - Periodo: $_periodoSeleccionado', style: pw.TextStyle(fontSize: 12)),
              pw.Divider(),
              pw.SizedBox(height: 20),
              ...salones.take(10).map((salon) {
                final s = salon as Map<String, dynamic>;
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(s['nombre'] ?? 'Salon', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Visitas: ${s['visitas'] ?? 0} - Gasto: ${_formatearMoneda((s['gasto_total'] ?? 0).toDouble())}'),
                      pw.SizedBox(height: 5),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );

      await _compartirPDF(pdf, 'mis_salones_visitados');
    } catch (e) {
      print('Error: $e');
      _mostrarError('Error al generar el reporte');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarReporteServicios() async {
    if (_datosReporte == null) return;

    try {
      setState(() => _isLoading = true);

      final pdf = pw.Document();
      final servicios = _datosReporte!['serviciosFrecuentes'] as List? ?? [];

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Mis Servicios Frecuentes', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('$_nombreCliente - Periodo: $_periodoSeleccionado', style: pw.TextStyle(fontSize: 12)),
              pw.Divider(),
              pw.SizedBox(height: 20),
              ...servicios.map((servicio) {
                final s = servicio as Map<String, dynamic>;
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text('${s['nombre'] ?? 'Servicio'}: ${s['cantidad'] ?? 0} veces'),
                );
              }).toList(),
            ],
          ),
        ),
      );

      await _compartirPDF(pdf, 'mis_servicios_frecuentes');
    } catch (e) {
      print('Error: $e');
      _mostrarError('Error al generar el reporte');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarHistorialCitas() async {
    if (_datosReporte == null) return;

    try {
      setState(() => _isLoading = true);

      final pdf = pw.Document();
      final citas = _datosReporte!['citas'] as List? ?? [];

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Mi Historial de Citas', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('$_nombreCliente - Periodo: $_periodoSeleccionado', style: pw.TextStyle(fontSize: 12)),
              pw.Divider(),
              pw.SizedBox(height: 20),
              ...citas.take(15).map((cita) {
                final c = cita as Map<String, dynamic>;
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${c['salon'] ?? 'Salon'} - ${c['estado'] ?? 'pendiente'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('${c['servicio'] ?? 'Servicio'} - ${_formatearMoneda((c['precio'] ?? 0).toDouble())}'),
                      pw.SizedBox(height: 5),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );

      await _compartirPDF(pdf, 'mi_historial_citas');
    } catch (e) {
      print('Error: $e');
      _mostrarError('Error al generar el reporte');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarGastosPorSalon() async {
    if (_datosGastosPorSalon == null) return;

    try {
      setState(() => _isLoading = true);

      final pdf = pw.Document();
      final salones = _datosGastosPorSalon!['salones'] as List? ?? [];
      final resumen = _datosGastosPorSalon!['resumen'] as Map<String, dynamic>?;

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Mis Gastos por Salon', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Comparativo para ayudarte a decidir', style: pw.TextStyle(fontSize: 12)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              
              // Resumen general
              if (resumen != null) ...[
                pw.Text('RESUMEN GENERAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Gasto Total: ${_formatearMoneda((resumen['gasto_total_general'] ?? 0).toDouble())}'),
                pw.Text('Gasto este Mes: ${_formatearMoneda((resumen['gasto_mes_general'] ?? 0).toDouble())}'),
                pw.Text('Gasto este Ano: ${_formatearMoneda((resumen['gasto_anio_general'] ?? 0).toDouble())}'),
                pw.SizedBox(height: 15),
                pw.Divider(),
                pw.SizedBox(height: 10),
              ],
              
              // Detalle por salón
              pw.Text('DETALLE POR SALON', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ...salones.map((salon) {
                final s = salon as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(s['nombre'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.SizedBox(height: 4),
                      pw.Text('Total (${s['citas_total']} citas): ${_formatearMoneda((s['gasto_total'] ?? 0).toDouble())}'),
                      pw.Text('Este mes (${s['citas_mes']} citas): ${_formatearMoneda((s['gasto_mes'] ?? 0).toDouble())}'),
                      pw.Text('Este ano (${s['citas_anio']} citas): ${_formatearMoneda((s['gasto_anio'] ?? 0).toDouble())}'),
                      pw.Divider(),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );

      await _compartirPDF(pdf, 'mis_gastos_por_salon');
    } catch (e) {
      print('Error: $e');
      _mostrarError('Error al generar el reporte');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _compartirPDF(pw.Document pdf, String nombreBase) async {
    try {
      final bytes = await pdf.save();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/${nombreBase}_$timestamp.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      final result = await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf')],
        subject: 'Mi Reporte - Beauteek',
        text: 'Reporte generado por Beauteek',
      );

      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte compartido exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error compartiendo PDF: $e');
      _mostrarError('Error al compartir el reporte');
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayDatos = _datosReporte != null;

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
          'Mis Reportes',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : Column(
              children: [
                // Selector de periodo
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _PeriodoChip(
                        label: 'Todos',
                        isSelected: _periodoSeleccionado == 'Todos',
                        onTap: () => _cambiarPeriodo('Todos'),
                      ),
                      const SizedBox(width: 12),
                      _PeriodoChip(
                        label: 'Mes',
                        isSelected: _periodoSeleccionado == 'Mes',
                        onTap: () => _cambiarPeriodo('Mes'),
                      ),
                      const SizedBox(width: 12),
                      _PeriodoChip(
                        label: 'Año',
                        isSelected: _periodoSeleccionado == 'Año',
                        onTap: () => _cambiarPeriodo('Año'),
                      ),
                    ],
                  ),
                ),

                // Mensaje de sin datos
                if (!hayDatos)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.primaryOrange, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No hay datos disponibles para este periodo',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Lista de reportes
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _ReporteCard(
                        icon: Icons.assessment_rounded,
                        iconColor: const Color(0xFF007AFF),
                        backgroundColor: const Color(0xFF0B1F2E),
                        titulo: 'Mi Resumen General',
                        onDownload: hayDatos ? _descargarResumenGeneral : null,
                      ),
                      const SizedBox(height: 16),
                      _ReporteCard(
                        icon: Icons.store_rounded,
                        iconColor: const Color(0xFF34C759),
                        backgroundColor: const Color(0xFF0D2538),
                        titulo: 'Mis Salones Visitados',
                        onDownload: hayDatos ? _descargarReporteSalones : null,
                      ),
                      const SizedBox(height: 16),
                      _ReporteCard(
                        icon: Icons.spa_rounded,
                        iconColor: const Color(0xFFFF9500),
                        backgroundColor: const Color(0xFF3B2612),
                        titulo: 'Mis Servicios Frecuentes',
                        onDownload: hayDatos ? _descargarReporteServicios : null,
                      ),
                      const SizedBox(height: 16),
                      _ReporteCard(
                        icon: Icons.history_rounded,
                        iconColor: const Color(0xFFAF8260),
                        backgroundColor: const Color(0xFF2A1F1A),
                        titulo: 'Mi Historial de Citas',
                        onDownload: hayDatos ? _descargarHistorialCitas : null,
                      ),
                      const SizedBox(height: 16),
                      _ReporteCard(
                        icon: Icons.analytics_rounded,
                        iconColor: const Color(0xFFFF3B30),
                        backgroundColor: const Color(0xFF3B1614),
                        titulo: 'Gastos por Salon',
                        onDownload: (_datosGastosPorSalon != null) ? _descargarGastosPorSalon : null,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PeriodoChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodoChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryOrange : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ReporteCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String titulo;
  final VoidCallback? onDownload;

  const _ReporteCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.titulo,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDownload,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.file_download_outlined,
                color: onDownload != null ? iconColor : iconColor.withOpacity(0.3),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
