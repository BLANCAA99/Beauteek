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
  // 🎨 Tema Beauteek
  static const Color _backgroundColor = Color(0xFF18100A);
  static const Color _cardColor = Color(0xFF24170F);
  static const Color _fieldColor = Color(0xFF2D2117);
  static const Color _primaryOrange = Color(0xFFEA963A);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB7AEA5);

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

      if (response.statusCode == 201) {
        if (!mounted) return;

        // 🔔 Modal personalizado al estilo "restablecer contraseña"
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.fromLTRB(24, 28, 24, 24), // interior
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4EC),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE6F6EC),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Color(0xFF2E9248),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '¡Método de pago\nverificado!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F130C),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tu tarjeta ha sido verificada exitosamente.\n\nAhora puedes continuar con el registro de tu salón.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF6D6257),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // cerrar modal
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const SalonRegistrationFormPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Continuar con el registro',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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
          },
        );
      } else {
        String msg = 'Error al validar tarjeta';
        try {
          final data = json.decode(response.body);
          msg = data['message'] ?? data['error'] ?? msg;
        } catch (_) {}
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
        leading: const BackButton(color: _textPrimary),
        title: const Text(
          'Métodos de Pago',
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // Mis tarjetas (espacio para las que ya tenga)
            const SizedBox(height: 8),
            const Text(
              'Mis Tarjetas',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.credit_card_outlined,
                    color: _textSecondary,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aquí verás tus tarjetas guardadas cuando agregues una.',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Agregar Tarjeta',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ingresa los datos de tu tarjeta para verificar tu método de pago.',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Tipo de tarjeta
            Row(
              children: [
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      unselectedWidgetColor: _textSecondary,
                    ),
                    child: RadioListTile<String>(
                      title: const Text(
                        'Débito',
                        style: TextStyle(color: _textPrimary),
                      ),
                      value: 'debito',
                      activeColor: _primaryOrange,
                      groupValue: _tipoTarjeta,
                      onChanged: (value) =>
                          setState(() => _tipoTarjeta = value!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      unselectedWidgetColor: _textSecondary,
                    ),
                    child: RadioListTile<String>(
                      title: const Text(
                        'Crédito',
                        style: TextStyle(color: _textPrimary),
                      ),
                      value: 'credito',
                      activeColor: _primaryOrange,
                      groupValue: _tipoTarjeta,
                      onChanged: (value) =>
                          setState(() => _tipoTarjeta = value!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Número de tarjeta
            _buildTextField(
              controller: _numeroTarjetaController,
              label: 'Número de la tarjeta *',
              hint: '0000 0000 0000 0000',
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
              label: 'Nombre en la tarjeta *',
              hint: 'Nombre Apellido',
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
                    label: 'Fecha de Vencimiento *',
                    hint: 'MM/AA',
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
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
              value: _bancoSeleccionado,
              dropdownColor: _cardColor,
              decoration: InputDecoration(
                hintText: 'Selecciona tu banco',
                hintStyle:
                    const TextStyle(color: _textSecondary, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.account_balance, color: _textSecondary),
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
              onChanged: (value) => setState(() => _bancoSeleccionado = value),
              validator: (value) =>
                  value == null ? 'Selecciona un banco' : null,
            ),
            const SizedBox(height: 24),

            // Nota de seguridad
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF132217),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(Icons.verified_user, color: Color(0xFF36C26B)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu información de pago está segura y encriptada.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón principal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Text(
                        'Guardar Tarjeta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 TextField estilizado
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
          maxLength: maxLength,
          inputFormatters: inputFormatters,
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