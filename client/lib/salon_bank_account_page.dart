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
  // 🎨 Tema Beauteek (mismo estilo que el mock)
  static const Color _backgroundColor = Color(0xFF18100A);
  static const Color _fieldColor = Color(0xFF222736);
  static const Color _primaryOrange = Color(0xFFFF9240);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB7B9C0);

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
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 30));

      print('📥 Status: ${response.statusCode}');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Cuenta bancaria registrada! Ahora agrega tus servicios.',
            ),
          ),
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
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: _textPrimary),
        title: const Text(
          'Cuenta bancaria',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const SizedBox(height: 16),
            const Text(
              'Registra tu cuenta bancaria',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para recibir los pagos de tus servicios',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Banco
            const Text(
              'Banco *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _bancoController.text.isEmpty
                  ? null
                  : _bancoController.text,
              dropdownColor: _fieldColor,
              iconEnabledColor: _textSecondary,
              decoration: InputDecoration(
                hintText: 'Selecciona tu banco',
                hintStyle: const TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: _fieldColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _bancosHonduras.map((banco) {
                return DropdownMenuItem(
                  value: banco,
                  child: Text(
                    banco,
                    style: const TextStyle(color: _textPrimary),
                  ),
                );
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
            const SizedBox(height: 18),

            // Tipo de cuenta
            const Text(
              'Tipo de cuenta *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(
                unselectedWidgetColor: _textSecondary,
                radioTheme: RadioThemeData(
                  fillColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return _primaryOrange;
                    }
                    return _textSecondary;
                  }),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Ahorro',
                        style: TextStyle(color: _textPrimary),
                      ),
                      value: 'ahorro',
                      groupValue: _tipoCuenta,
                      onChanged: (value) =>
                          setState(() => _tipoCuenta = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Corriente',
                        style: TextStyle(color: _textPrimary),
                      ),
                      value: 'corriente',
                      groupValue: _tipoCuenta,
                      onChanged: (value) =>
                          setState(() => _tipoCuenta = value!),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Número de cuenta
            _buildTextField(
              controller: _numeroCuentaController,
              label: 'Número de cuenta *',
              hint: 'Ej: 1234567890',
              keyboardType: TextInputType.number,
              icon: Icons.account_balance,
            ),
            const SizedBox(height: 18),

            // Nombre del titular
            _buildTextField(
              controller: _nombreTitularController,
              label: 'Nombre del titular *',
              hint: 'Nombre completo',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 18),

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
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111A2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2E4C8F),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(
                    Icons.info_outline,
                    color: Color(0xFF4C7DFF),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu información bancaria está protegida y solo se usará para procesar pagos.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón continuar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 5,
                  backgroundColor: _primaryOrange,
                  foregroundColor: _textPrimary,
                ).copyWith(
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.disabled)) {
                      return _primaryOrange.withOpacity(0.5);
                    }
                    return _primaryOrange;
                  }),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Text(
                        'Siguiente: Agregar Servicios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 TextField reutilizable con estilo oscuro
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
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: _textSecondary, fontSize: 14),
            prefixIcon:
                icon != null ? Icon(icon, color: _textSecondary) : null,
            filled: true,
            fillColor: _fieldColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
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