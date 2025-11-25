import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'api_constants.dart';
import 'theme/app_theme.dart';

class ReportesSalonPage extends StatefulWidget {
  const ReportesSalonPage({Key? key}) : super(key: key);

  @override
  State<ReportesSalonPage> createState() => _ReportesSalonPageState();
}

class _ReportesSalonPageState extends State<ReportesSalonPage> {
  bool _isLoading = false;
  int _totalClientes = 0;
  List<Map<String, dynamic>> _clientes = [];
  String? _comercioId;
  String? _nombreSalon;
  String _periodoSeleccionado = 'Semana';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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

      if (comerciosResponse.statusCode == 200) {
        final List<dynamic> comercios = json.decode(comerciosResponse.body);
        final miComercio = comercios.firstWhere(
          (c) => c['uid_negocio'] == user.uid,
          orElse: () => null,
        );

        if (miComercio != null) {
          _comercioId = miComercio['id'];
          _nombreSalon = miComercio['nombre'] ?? 'Mi Salón';

          // 2. Obtener citas del comercio
          final citasUrl = Uri.parse('$apiBaseUrl/citas/usuario/${user.uid}');
          final citasResponse = await http.get(
            citasUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          );

          if (citasResponse.statusCode == 200) {
            final List<dynamic> citas = json.decode(citasResponse.body);

            // 3. Filtrar citas por comercio_id
            final citasDelComercio = citas.where((cita) {
              return cita['comercio_id'] == _comercioId;
            }).toList();

            // 4. Extraer clientes únicos
            final clientesUnicos = <String, Map<String, dynamic>>{};

            for (var cita in citasDelComercio) {
              final clienteId = cita['usuario_cliente_id'];
              if (clienteId != null && !clientesUnicos.containsKey(clienteId)) {
                clientesUnicos[clienteId] = {
                  'cliente_id': clienteId,
                  'servicio': cita['servicio_nombre'] ?? 'N/A',
                  'fecha_primera_cita': cita['fecha_hora'],
                  'total_citas': 1,
                };
              } else if (clienteId != null) {
                clientesUnicos[clienteId]!['total_citas']++;
              }
            }

            setState(() {
              _totalClientes = clientesUnicos.length;
              _clientes = clientesUnicos.values.toList();
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('❌ Error cargando datos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarReportePDF() async {
    try {
      setState(() => _isLoading = true);

      final pdf = pw.Document();

      // Crear el PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Encabezado
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Reporte de Clientes',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    _nombreSalon ?? 'Mi Salón',
                    style: pw.TextStyle(
                      fontSize: 18,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Resumen
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total de Clientes:',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '$_totalClientes',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Tabla de clientes
            pw.Text(
              'Detalle de Clientes',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 16),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                // Encabezado de tabla
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '#',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'ID Cliente',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Total Citas',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                // Filas de datos
                ..._clientes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final cliente = entry.value;
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${index + 1}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          cliente['cliente_id']?.substring(0, 8) ?? 'N/A',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${cliente['total_citas'] ?? 0}'),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 30),

            // Pie de página
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generado por Beauteek - Sistema de Gestión de Salones',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

      // Guardar y compartir
      final bytes = await pdf.save();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Crear archivo temporal
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/reporte_clientes_$timestamp.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      setState(() => _isLoading = false);

      // Compartir archivo
      final result = await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf')],
        subject: 'Reporte de Clientes - $_nombreSalon',
        text: 'Reporte de Clientes\nTotal: $_totalClientes clientes únicos',
      );

      if (mounted) {
        if (result.status == ShareResultStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Reporte compartido exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error generando reporte: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar el reporte: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
          'Reportes Detallados',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : Column(
              children: [
                // Selector de periodo
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _PeriodoChip(
                        label: 'Semana',
                        isSelected: _periodoSeleccionado == 'Semana',
                        onTap: () =>
                            setState(() => _periodoSeleccionado = 'Semana'),
                      ),
                      const SizedBox(width: 12),
                      _PeriodoChip(
                        label: 'Mes',
                        isSelected: _periodoSeleccionado == 'Mes',
                        onTap: () =>
                            setState(() => _periodoSeleccionado = 'Mes'),
                      ),
                      const SizedBox(width: 12),
                      _PeriodoChip(
                        label: 'Año',
                        isSelected: _periodoSeleccionado == 'Año',
                        onTap: () =>
                            setState(() => _periodoSeleccionado = 'Año'),
                      ),
                    ],
                  ),
                ),

                // Lista de reportes
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _ReporteCard(
                        icon: Icons.bar_chart_rounded,
                        iconColor: const Color(0xFFFF9500),
                        backgroundColor: const Color(0xFF3B2612),
                        titulo: 'Reporte de Ingresos Totales',
                        onDownload: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Función en desarrollo'),
                              backgroundColor: AppTheme.primaryOrange,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _ReporteCard(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFF34C759),
                        backgroundColor: const Color(0xFF0D2538),
                        titulo: 'Reporte de Servicios Más Populares',
                        onDownload: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Función en desarrollo'),
                              backgroundColor: AppTheme.primaryOrange,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _ReporteCard(
                        icon: Icons.person_add_rounded,
                        iconColor: const Color(0xFF007AFF),
                        backgroundColor: const Color(0xFF0B1F2E),
                        titulo: 'Reporte de Nuevos Clientes',
                        onDownload: _totalClientes > 0
                            ? _descargarReportePDF
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _ReporteCard(
                        icon: Icons.people_alt_rounded,
                        iconColor: const Color(0xFFAF8260),
                        backgroundColor: const Color(0xFF2A1F1A),
                        titulo: 'Reporte de Ocupación por Empleado',
                        hasDownload: false,
                      ),
                      const SizedBox(height: 16),
                      _ReporteCard(
                        icon: Icons.shopping_bag_rounded,
                        iconColor: const Color(0xFF34C759),
                        backgroundColor: const Color(0xFF0D2538),
                        titulo: 'Reporte de Venta de Productos',
                        onDownload: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Función en desarrollo'),
                              backgroundColor: AppTheme.primaryOrange,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _ReporteCard(
                        icon: Icons.event_busy_rounded,
                        iconColor: const Color(0xFF007AFF),
                        backgroundColor: const Color(0xFF0B1F2E),
                        titulo: 'Reporte de Citas Canceladas',
                        onDownload: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Función en desarrollo'),
                              backgroundColor: AppTheme.primaryOrange,
                            ),
                          );
                        },
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
  final bool hasDownload;

  const _ReporteCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.titulo,
    this.onDownload,
    this.hasDownload = true,
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
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
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
          if (hasDownload)
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
                  color: iconColor,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
