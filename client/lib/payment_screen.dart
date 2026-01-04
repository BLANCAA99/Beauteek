import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'api_constants.dart';

class PaymentScreen extends StatefulWidget {
  final String citaId;
  final double monto;
  final String salonName;
  final double? precioOriginal;
  final double? descuento;
  final bool? crearCitaDespuesPago;
  final Map<String, dynamic>? datosCita;

  const PaymentScreen({
    Key? key,
    required this.citaId,
    required this.monto,
    required this.salonName,
    this.precioOriginal,
    this.descuento,
    this.crearCitaDespuesPago,
    this.datosCita,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isProcessing = false;
  // NUEVO: Sin comisión al cliente
  double get total => widget.monto;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pagar Cita'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111418)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF111418),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.salonName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111418),
                ),
              ),
              const SizedBox(height: 20),

              // Resumen de pago
              Card(
                elevation: 0,
                color: Color(0xFFF0F2F4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (widget.precioOriginal != null &&
                          widget.descuento != null) ...[
                        _buildPriceRow(
                            'Precio original', widget.precioOriginal!),
                        const SizedBox(height: 8),
                        _buildDiscountRow(
                            'Descuento (-${widget.descuento!.toStringAsFixed(0)}%)',
                            widget.precioOriginal! - widget.monto),
                        Divider(color: Color(0xFF637588).withOpacity(0.3)),
                        _buildPriceRow('Total a pagar', total, isBold: true),
                      ] else ...[
                        _buildPriceRow('Valor del servicio', widget.monto),
                        Divider(color: Color(0xFF637588).withOpacity(0.3)),
                        _buildPriceRow('Total a pagar', total, isBold: true),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Datos de la tarjeta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111418),
                ),
              ),
              const SizedBox(height: 16),

              // Número de tarjeta
              TextFormField(
                controller: _cardNumberController,
                decoration: InputDecoration(
                  labelText: 'Número de Tarjeta',
                  hintText: '1234 5678 9012 3456',
                  prefixIcon: Icon(Icons.credit_card, color: Color(0xFFEA963A)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFFF0F2F4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFFEA963A)),
                  ),
                  filled: true,
                  fillColor: Color(0xFFF0F2F4),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CardNumberFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el número de tarjeta';
                  }
                  // Validación simplificada: solo verifica que tenga dígitos
                  if (value.replaceAll(' ', '').length < 13) {
                    return 'Número de tarjeta muy corto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Nombre en la tarjeta
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre en la Tarjeta',
                  prefixIcon:
                      Icon(Icons.person_outline, color: Color(0xFFEA963A)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFFF0F2F4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFFEA963A)),
                  ),
                  filled: true,
                  fillColor: Color(0xFFF0F2F4),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Vencimiento y CVV
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      decoration: InputDecoration(
                        labelText: 'Vencimiento',
                        hintText: 'MM/AA',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFF0F2F4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFEA963A)),
                        ),
                        filled: true,
                        fillColor: Color(0xFFF0F2F4),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpiryDateFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        hintText: '123',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFF0F2F4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFEA963A)),
                        ),
                        filled: true,
                        fillColor: Color(0xFFF0F2F4),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        if (value.length < 3) {
                          return 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Botón de pago
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFEA963A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Pagar L${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '-L${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: Color(0xFF111418),
            ),
          ),
          Text(
            'L${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: Color(0xFF111418),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final idToken = await user.getIdToken();

      // 🔹 SI NECESITA CREAR LA CITA PRIMERO (pago en línea adelantado)
      String citaIdFinal = widget.citaId;

      if (widget.crearCitaDespuesPago == true && widget.datosCita != null) {
        // Primero crear la cita
        final citaUrl = Uri.parse('$apiBaseUrl/citas');
        final citaResponse = await http
            .post(
              citaUrl,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: json.encode(widget.datosCita),
            )
            .timeout(const Duration(seconds: 30));

        if (citaResponse.statusCode != 201) {
          throw Exception('No se pudo crear la cita: ${citaResponse.body}');
        }

        // Extraer el ID de la cita creada
        final citaData = json.decode(citaResponse.body);
        if (citaData.containsKey('citaId')) {
          citaIdFinal = citaData['citaId']?.toString() ?? '';
        } else if (citaData.containsKey('id')) {
          citaIdFinal = citaData['id']?.toString() ?? '';
        } else if (citaData.containsKey('cita_id')) {
          citaIdFinal = citaData['cita_id']?.toString() ?? '';
        } else if (citaData is Map && citaData.containsKey('cita')) {
          citaIdFinal = citaData['cita']?['id']?.toString() ?? '';
        }

        if (citaIdFinal.isEmpty) {
          throw Exception('No se pudo obtener el ID de la cita creada');
        }
      }

      // Ahora sí procesar el pago con el citaId correcto
      final payload = {
        'citaId': citaIdFinal,
        'clienteId': user.uid,
        'monto': widget.monto,
        'numeroTarjeta': _cardNumberController.text.replaceAll(' ', ''),
        'nombreTitular': _nameController.text,
        'fechaVencimiento': _expiryController.text,
        'cvv': _cvvController.text,
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/pagos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final pagoData = json.decode(response.body);

        // Mostrar diálogo de éxito con opción de descargar recibo
        await _mostrarDialogoExito(pagoData);

        // Retornar true para indicar que el pago fue exitoso
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        final error = json.decode(response.body);
        throw Exception(
            error['mensaje'] ?? error['error'] ?? 'Error al procesar el pago');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _mostrarDialogoExito(Map<String, dynamic> pagoData) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¡Pago Exitoso!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu pago ha sido procesado correctamente.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                      'Monto pagado', 'L${widget.monto.toStringAsFixed(2)}'),
                  const Divider(),
                  _buildInfoRow('Referencia', pagoData['id'] ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '¿Deseas descargar tu recibo?',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ahora no', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await _generarYDescargarRecibo(pagoData);
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.download, color: Colors.white),
            label: const Text('Descargar Recibo',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA963A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _generarYDescargarRecibo(Map<String, dynamic> pagoData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final pdf = pw.Document();
      final ahora = DateTime.now();
      final fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(ahora);

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('RECIBO DE PAGO',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Beauteek - Plataforma de Belleza',
                  style: pw.TextStyle(fontSize: 12)),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Text('INFORMACION DEL PAGO',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Fecha: $fechaStr'),
              pw.Text('Referencia: ${pagoData['id'] ?? 'N/A'}'),
              pw.Text(
                  'Cliente: ${user.displayName ?? user.email ?? 'Cliente'}'),
              pw.SizedBox(height: 20),
              pw.Text('DETALLES DEL SERVICIO',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Salon: ${widget.salonName}'),
              pw.Text('Cita ID: ${widget.citaId}'),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              if (widget.precioOriginal != null &&
                  widget.descuento != null) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Precio original:'),
                    pw.Text('L${widget.precioOriginal!.toStringAsFixed(2)}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        'Descuento (-${widget.descuento!.toStringAsFixed(0)}%):'),
                    pw.Text(
                        '-L${(widget.precioOriginal! - widget.monto).toStringAsFixed(2)}'),
                  ],
                ),
                pw.Divider(),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL PAGADO:',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('L${widget.monto.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Gracias por usar Beauteek',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Este es un comprobante de pago electronico',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      );

      final bytes = await pdf.save();
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/recibo_pago_$timestamp.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      final result = await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf')],
        subject: 'Recibo de Pago - Beauteek',
        text: 'Tu recibo de pago por L${widget.monto.toStringAsFixed(2)}',
      );

      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recibo descargado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar recibo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
