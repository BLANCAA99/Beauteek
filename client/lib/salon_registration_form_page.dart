import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'inicio.dart';
import 'api_constants.dart';
import 'salon_address_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalonRegistrationFormPage extends StatefulWidget {
  const SalonRegistrationFormPage({Key? key}) : super(key: key);

  @override
  _SalonRegistrationFormPageState createState() =>
      _SalonRegistrationFormPageState();
}

class _SalonRegistrationFormPageState extends State<SalonRegistrationFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores para el formulario
  final _salonNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _salonPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkEmulatorMode();
  }

  // Verificar si estamos en modo emulador
  Future<void> _checkEmulatorMode() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('Usuario actual: ${currentUser.email} (${currentUser.uid})');
      print('Modo: Producción');
    }
  }

  @override
  void dispose() {
    _salonNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _salonPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if ((_passwordController.text.trim()).length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // PRUEBA DE CONECTIVIDAD
      print('🧪 Probando conectividad...');
      final testUrl = Uri.parse('$apiBaseUrl/comercios');
      final testResponse = await http.get(testUrl).timeout(const Duration(seconds: 5));
      print('✅ Conectividad OK - Status: ${testResponse.statusCode}');

      // Obtener el UID del cliente propietario (usuario actual en sesión)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Debes iniciar sesión primero');
      }

      print('📍 Usuario actual: ${currentUser.uid}');

      // Obtener el token de autenticación
      final idToken = await currentUser.getIdToken();
      print('🔑 Token obtenido: ${idToken?.substring(0, 20)}...');

      // Llamar al API para crear el salón (paso 1)
      final payload = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'nombre': _salonNameController.text.trim(),
        'telefono': _salonPhoneController.text.trim(),
      };

      print('📤 Enviando payload: ${json.encode(payload)}');

      final url = Uri.parse('$apiBaseUrl/comercios/register-salon-step1');
      print('🌐 URL: $url');
      print('🔍 apiBaseUrl: $apiBaseUrl'); // Debug adicional

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 45));

      print('📥 Status code: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final String comercioId = responseData['comercioId'];
        final String uidNegocio = responseData['uidNegocio'];

        print('✅ Comercio creado: $comercioId');

        if (!mounted) return;

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Salón creado! Ahora, agrega la dirección.'))
        );

        // Navegar a la siguiente página
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SalonAddressPage(
              comercioId: comercioId,
              uidNegocio: uidNegocio,
            ),
          ),
        );

      } else {
        String msg = 'Error al registrar el salón';
        try {
          final data = json.decode(response.body);
          msg = data['message'] ?? data['error'] ?? data['details']?.toString() ?? msg;
          print('❌ Error del servidor: $msg');
        } catch (e) {
          print('❌ Error parseando respuesta: $e');
        }
        throw Exception(msg);
      }
    } on http.ClientException catch (e) {
      print('🔌 Error de conexión: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Verifica que el servidor esté corriendo.'))
      );
    } on FormatException catch (e) {
      print('📝 Error de formato: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error en el formato de datos.'))
      );
    } catch (e) {
      print('❌ Error general: $e');
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
      ),
      validator: (value) =>
          (isRequired && (value == null || value.isEmpty))
              ? 'Este campo es requerido'
              : null,
    );
  }

  // Las funciones _buildHorarioRow y _buildServicioRow se han eliminado.
  // Se moverán a la página de registro de horarios/servicios.
}