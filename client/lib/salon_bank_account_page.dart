import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'salon_services_page.dart'; // Crearemos esta página después

class SalonBankAccountPage extends StatefulWidget {
  final String comercioId;
  final String uidNegocio;

  const SalonBankAccountPage({
    Key? key,
    required this.comercioId,
    required this.uidNegocio,
  }) : super(key: key);

  @override
  State<SalonBankAccountPage> createState() => _SalonBankAccountPageState();
}

class _SalonBankAccountPageState extends State<SalonBankAccountPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores
  final _bancoController = TextEditingController();
  final _numeroCuentaController = TextEditingController();
  final _nombreTitularController = TextEditingController();
  final _identificacionController = TextEditingController();

  String _tipoCuenta = 'ahorro';

  final List<String> _bancosHonduras = [
    'Banco Atlántida',
    'Banco de Occidente',
    'Banco del País',
    'Banco Ficohsa',
    'Banco Lafise',
    'Banco Promerica',
    'BAC Honduras',
    'Davivienda',
    'Otro',
  ];

  @override
  void dispose() {
    _bancoController.dispose();
    _numeroCuentaController.dispose();
    _nombreTitularController.dispose();
    _identificacionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Sesión expirada');
      }

      final idToken = await currentUser.getIdToken();

      final payload = {
        'comercioId': widget.comercioId,
        'banco': _bancoController.text.trim(),
        'tipo_cuenta': _tipoCuenta,
        'numero_cuenta': _numeroCuentaController.text.trim(),
        'nombre_titular': _nombreTitularController.text.trim(),
        'identificacion_titular': _identificacionController.text.trim(),
      };

      print('📤 Enviando datos bancarios: ${json.encode(payload)}');

      final url = Uri.parse('$apiBaseUrl/comercios/register-salon-step3');
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

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cuenta bancaria registrada! Ahora agrega tus servicios.'))
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SalonServicesPage(
              comercioId: widget.comercioId,
              uidNegocio: widget.uidNegocio,
            ),
          ),
        );
      } else {
        String msg = 'Error al registrar cuenta bancaria';
        try {
          final data = json.decode(response.body);
          msg = data['message'] ?? data['error'] ?? msg;
        } catch (e) {
          print('Error parseando respuesta: $e');
        }
        throw Exception(msg);
      }
    } catch (e) {
      print('❌ Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'))
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
          'Cuenta bancaria',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Registra tu cuenta bancaria',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para recibir los pagos de tus servicios',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Banco
            const Text('Banco *', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: null,
              decoration: InputDecoration(
                hintText: 'Selecciona tu banco',
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
              onChanged: (value) {
                if (value != null) _bancoController.text = value;
              },
              validator: (value) {
                if (_bancoController.text.isEmpty) {
                  return 'Selecciona un banco';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Tipo de cuenta
            const Text('Tipo de cuenta *', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Ahorro'),
                    value: 'ahorro',
                    groupValue: _tipoCuenta,
                    onChanged: (value) => setState(() => _tipoCuenta = value!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Corriente'),
                    value: 'corriente',
                    groupValue: _tipoCuenta,
                    onChanged: (value) => setState(() => _tipoCuenta = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Número de cuenta
            _buildTextField(
              controller: _numeroCuentaController,
              label: 'Número de cuenta *',
              hint: 'Ej: 1234567890',
              keyboardType: TextInputType.number,
              icon: Icons.account_balance,
            ),
            const SizedBox(height: 16),

            // Nombre del titular
            _buildTextField(
              controller: _nombreTitularController,
              label: 'Nombre del titular *',
              hint: 'Nombre completo',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),

            // Identificación
            _buildTextField(
              controller: _identificacionController,
              label: 'Identificación del titular *',
              hint: 'DNI o RTN',
              keyboardType: TextInputType.number,
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 24),

            // Nota informativa
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tu información bancaria está protegida y solo se usará para procesar pagos.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón continuar
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5B1A8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Siguiente: Agregar Servicios',
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
    TextInputType? keyboardType,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) =>
              value == null || value.isEmpty ? 'Este campo es requerido' : null,
        ),
      ],
    );
  }
}
