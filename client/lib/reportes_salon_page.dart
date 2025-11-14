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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111418)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reportes Detallados',
          style: TextStyle(
            color: Color(0xFF111418),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA963A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card de total de clientes
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEA963A), Color(0xFFFF6B9D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA963A).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.people,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Total de Clientes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '$_totalClientes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _totalClientes == 1 ? 'cliente único' : 'clientes únicos',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botón de descarga PDF
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _totalClientes > 0 ? _descargarReportePDF : null,
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: const Text(
                        'Descargar Reporte PDF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Lista de clientes
                  if (_clientes.isNotEmpty) ...[
                    const Text(
                      'Detalle de Clientes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111418),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._clientes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final cliente = entry.value;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFEA963A).withOpacity(0.1),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFFEA963A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cliente #${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111418),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${cliente['total_citas']} citas realizadas',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF637588),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
    );
  }
}
