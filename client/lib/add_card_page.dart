import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'salon_registration_form_page.dart';

class AddCardPage extends StatefulWidget {
  const AddCardPage({Key? key}) : super(key: key);

  @override
  State<AddCardPage> createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _numeroTarjetaController = TextEditingController();
  final _nombreTitularController = TextEditingController();
  final _fechaExpiracionController = TextEditingController();
  final _cvvController = TextEditingController();

  String _tipoTarjeta = 'debito';
  String? _bancoSeleccionado;

  final List<String> _bancosHonduras = [
    'Banco Atlántida',
    'Banco de Occidente',
    'Banco del País',
    'Banco Ficohsa',
    'Banco Lafise',
    'Banco Promerica',
    'BAC Honduras',
    'Davivienda',
  ];

  @override
  void dispose() {
    _numeroTarjetaController.dispose();
    _nombreTitularController.dispose();
    _fechaExpiracionController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _submitCard() async {
    if (!_formKey.currentState!.validate()) return;

    if (_bancoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona tu banco')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Si no hay usuario autenticado, redirigir a login
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final idToken = await currentUser.getIdToken();

      final payload = {
        'numero_tarjeta': _numeroTarjetaController.text.replaceAll(' ', ''),
        'nombre_titular': _nombreTitularController.text.trim(),
        'fecha_expiracion': _fechaExpiracionController.text.trim(),
        'cvv': _cvvController.text.trim(),
        'tipo': _tipoTarjeta,
        'banco': _bancoSeleccionado,
      };

      print('📤 Enviando tarjeta: ${json.encode(payload)}');

      final url = Uri.parse('$apiBaseUrl/api/tarjetas');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      print('📥 Status: ${response.statusCode}');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 201) {
        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 64),
                SizedBox(height: 16),
                Text('¡Método de pago verificado!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Tu tarjeta ha sido verificada exitosamente.\n\nAhora puedes continuar con el registro de tu salón.',
              textAlign: TextAlign.center,
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Cerrar dialog
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SalonRegistrationFormPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA963A),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Continuar con el registro',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      } else {
        String msg = 'Error al validar tarjeta';
        try {
          final data = json.decode(response.body);
          msg = data['message'] ?? data['error'] ?? msg;
        } catch (e) {}
        throw Exception(msg);
      }
    } catch (e) {
      print('❌ Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Método de pago',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Agrega tu tarjeta',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para verificar tu método de pago y activar tu suscripción',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Tipo de tarjeta
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Débito'),
                    value: 'debito',
                    groupValue: _tipoTarjeta,
                    onChanged: (value) => setState(() => _tipoTarjeta = value!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Crédito'),
                    value: 'credito',
                    groupValue: _tipoTarjeta,
                    onChanged: (value) => setState(() => _tipoTarjeta = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Número de tarjeta
            _buildTextField(
              controller: _numeroTarjetaController,
              label: 'Número de tarjeta *',
              hint: '1234 5678 9012 3456',
              icon: Icons.credit_card,
              keyboardType: TextInputType.number,
              maxLength: 19,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CardNumberFormatter(),
              ],
            ),
            const SizedBox(height: 16),

            // Nombre del titular
            _buildTextField(
              controller: _nombreTitularController,
              label: 'Nombre del titular *',
              hint: 'Como aparece en la tarjeta',
              icon: Icons.person_outline,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
              ],
            ),
            const SizedBox(height: 16),

            // Fecha y CVV
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _fechaExpiracionController,
                    label: 'Vencimiento *',
                    hint: 'MM/YY',
                    icon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _DateFormatter(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _cvvController,
                    label: 'CVV *',
                    hint: '123',
                    icon: Icons.lock_outline,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Banco
            const Text('Banco *', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _bancoSeleccionado,
              decoration: InputDecoration(
                hintText: 'Selecciona tu banco',
                prefixIcon: const Icon(Icons.account_balance, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _bancosHonduras.map((banco) {
                return DropdownMenuItem(value: banco, child: Text(banco));
              }).toList(),
              onChanged: (value) => setState(() => _bancoSeleccionado = value),
              validator: (value) => value == null ? 'Selecciona un banco' : null,
            ),
            const SizedBox(height: 24),

            // Nota de seguridad
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tu información está protegida y encriptada.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón
            ElevatedButton(
              onPressed: _isLoading ? null : _submitCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA963A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Verificar tarjeta',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            counterText: '',
          ),
          validator: (value) =>
              value == null || value.isEmpty ? 'Este campo es requerido' : null,
        ),
      ],
    );
  }
}

// Formatters personalizados
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _DateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
