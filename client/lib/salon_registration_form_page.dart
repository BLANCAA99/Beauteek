import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'inicio.dart';
import 'api_constants.dart';
import 'salon_address_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_card_page.dart';

class SalonRegistrationFormPage extends StatefulWidget {
  const SalonRegistrationFormPage({Key? key}) : super(key: key);

  @override
  _SalonRegistrationFormPageState createState() =>
      _SalonRegistrationFormPageState();
}

class _SalonRegistrationFormPageState extends State<SalonRegistrationFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _tarjetaVerificada = false; // Agregar flag

  // Controladores para el formulario
  final _salonNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _salonPhoneController = TextEditingController();
  final _rtnController = TextEditingController(); // Agregado

  @override
  void initState() {
    super.initState();
    _checkEmulatorMode();
    _verificarTarjeta();
  }

  // Verificar si estamos en modo emulador
  Future<void> _checkEmulatorMode() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('Usuario actual: ${currentUser.email} (${currentUser.uid})');
      print('Modo: Producción');
    }
  }

  // Verificar si el usuario tiene tarjeta registrada
  Future<void> _verificarTarjeta() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tarjetas_usuarios')
          .where('usuario_id', isEqualTo: currentUser.uid)
          .where('activa', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        
        // Esperar un frame para que el widget esté completamente construido
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Column(
                children: [
                  Icon(Icons.credit_card, color: Color(0xFFEA963A), size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Método de pago requerido',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              content: const Text(
                'Para registrar tu salón necesitas agregar un método de pago para tu suscripción.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // Volver a inicio
                  },
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AddCardPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA963A),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Agregar tarjeta',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        });
      } else {
        print('✅ Usuario tiene tarjeta registrada');
        setState(() => _tarjetaVerificada = true);
      }
    } catch (e) {
      print('❌ Error verificando tarjeta: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al verificar método de pago')),
      );
    }
  }

  @override
  void dispose() {
    _salonNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _salonPhoneController.dispose();
    _rtnController.dispose(); // Agregado
    super.dispose();
  }

  Future<void> _submitForm() async {
    // Verificar tarjeta antes de continuar
    if (!_tarjetaVerificada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Primero debes agregar un método de pago')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if ((_passwordController.text.trim()).length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres.')),
      );
      return;
    }

    // Validar RTN
    if (_rtnController.text.trim().length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El RTN debe tener exactamente 14 dígitos.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Debes iniciar sesión primero');
      }

      final idToken = await currentUser.getIdToken();

      // ✅ USAR API EN LUGAR DE FIRESTORE
      final payload = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'nombre': _salonNameController.text.trim(),
        'telefono': _salonPhoneController.text.trim(),
        'rtn': _rtnController.text.trim(),
      };

      print('📤 Enviando payload: ${json.encode(payload)}');

      final url = Uri.parse('$apiBaseUrl/comercios/register-salon-step1');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      print('📥 Status code: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final String comercioId = responseData['comercioId'];
        final String uidNegocio = responseData['uidNegocio'];

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Salón creado! Ahora, agrega la dirección.'))
        );

        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SalonAddressPage(
              comercioId: comercioId,
              uidNegocio: uidNegocio,
            ),
          ),
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      print('[salon] Error: $e');
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
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          children: [
            const Text(
              '¡Registra tu salón\nahora mismo!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCEAE8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '0% de comisión durante los primeros 30 días',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Nombre del salón *'),
            _buildTextField(_salonNameController, 'Ej: Salón La Belleza',
                Icons.store_outlined),
            const SizedBox(height: 16),
            _buildSectionTitle('Email de la cuenta del salón *'),
            _buildTextField(_emailController, 'ejemplo@email.com',
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildSectionTitle('Contraseña para la cuenta del salón *'),
            _buildTextField(_passwordController, 'Mínimo 6 caracteres',
                Icons.lock_outline,
                isPassword: true),
            const SizedBox(height: 16),
            _buildSectionTitle('Teléfono del salón *'),
            _buildTextField(_salonPhoneController, '+504...',
                Icons.phone_in_talk_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildSectionTitle('RTN del salón *'),
            _buildTextField(
              _rtnController,
              '14 dígitos',
              Icons.business_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            // La sección de Dirección, Horarios y Servicios se ha eliminado de esta página.

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5B1A8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Siguiente: Añadir Dirección', // Texto del botón actualizado
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            Center(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                  children: [
                    TextSpan(text: '¿Eres estilista independiente? '),
                    TextSpan(
                      text: 'Regístrate aquí.',
                      style: TextStyle(
                          color: Color(0xFFF5B1A8), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData? icon, {
    TextInputType? keyboardType,
    bool hasSuffix = false,
    bool isRequired = true,
    bool enabled = true,
    bool isPassword = false,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      obscureText: isPassword,
      readOnly: readOnly,
      onTap: onTap,
      maxLength: controller == _rtnController ? 14 : null, // Limitar RTN a 14 dígitos
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        suffixIcon: hasSuffix ? const Icon(Icons.search, color: Colors.grey) : null,
        filled: true,
        fillColor: enabled ? Colors.grey.shade100 : Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        counterText: '', // Ocultar contador de caracteres
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es requerido';
        }
        if (controller == _rtnController && value != null && value.length != 14) {
          return 'El RTN debe tener 14 dígitos';
        }
        return null;
      },
    );
  }

  // Las funciones _buildHorarioRow y _buildServicioRow se han eliminado.
  // Se moverán a la página de registro de horarios/servicios.
}