import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'salon_address_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_card_page.dart';
import 'api_constants.dart';

class SalonRegistrationFormPage extends StatefulWidget {
  const SalonRegistrationFormPage({Key? key}) : super(key: key);

  @override
  _SalonRegistrationFormPageState createState() =>
      _SalonRegistrationFormPageState();
}

class _SalonRegistrationFormPageState extends State<SalonRegistrationFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _tarjetaVerificada = false;

  // Colores de tema
  static const Color _backgroundColor = Color(0xFF18100A);
  static const Color _fieldColor = Color(0xFF242424);
  static const Color _primaryOrange = Color(0xFFEA963A);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB7AEA5);

  // Controladores para el formulario
  final _salonNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _salonPhoneController = TextEditingController();
  final _rtnController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkEmulatorMode();
    _verificarTarjeta();
  }

  Future<void> _checkEmulatorMode() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      
    }
  }

  Future<void> _verificarTarjeta() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      final token = await currentUser.getIdToken();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/tarjetas'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> tarjetas = json.decode(response.body);
        final tarjetasActivas = tarjetas.where((t) => t['activa'] == true).toList();
        
        if (tarjetasActivas.isEmpty) {
          if (!mounted) return;

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                    ),
                    child: AlertDialog(
                      backgroundColor: const Color(0xFFFFF4EB),
                      insetPadding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      titlePadding: EdgeInsets.zero,
                      contentPadding:
                          const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      actionsPadding:
                          const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      title: null,
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.credit_card,
                              color: _primaryOrange,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Método de pago requerido',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F1F1F),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Para registrar tu salón necesitas agregar un método de pago para tu suscripción.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFF7B6F63),
                            ),
                          ),
                        ],
                      ),
                      actionsAlignment: MainAxisAlignment.spaceBetween,
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A8176),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const AddCardPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryOrange,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Agregar tarjeta',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          });
        } else {
          setState(() => _tarjetaVerificada = true);
        }
      }
    } catch (e) {
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
    _rtnController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _showVerificationDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF4EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text(
          'Verifica tu email',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F1F1F),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresa el código de 6 dígitos enviado a ${_emailController.text}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF7B6F63)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _verificationCodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Color(0xFF1F1F1F),
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _verificationCodeController.clear();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF8A8176)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_verificationCodeController.text.length == 6) {
                Navigator.of(context).pop();
                await _completarRegistroSalon();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código inválido')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'Verificar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completarRegistroSalon() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Debes iniciar sesión primero');
      }

      // Verificar el código
      final verifyResponse = await http.post(
        Uri.parse('$apiBaseUrl/api/users/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'code': _verificationCodeController.text.trim(),
        }),
      );

      if (verifyResponse.statusCode != 200) {
        throw Exception('Código de verificación incorrecto');
      }

      // Proceder con el registro del salón
      final idToken = await currentUser.getIdToken();

      final payload = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'nombre': _salonNameController.text.trim(),
        'telefono': _salonPhoneController.text.trim(),
        'rtn': _rtnController.text.trim(),
      };

      final url = Uri.parse('$apiBaseUrl/comercios/register-salon-step1');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final String comercioId = responseData['comercioId'];
        final String uidNegocio = responseData['uidNegocio'];

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salón creado! Ahora, agrega la dirección.')),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_tarjetaVerificada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero debes agregar un método de pago')),
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

    if (_rtnController.text.trim().length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El RTN debe tener exactamente 14 dígitos.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Enviar código de verificación
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/users/send-verification-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': _emailController.text.trim()}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código enviado a tu email')),
        );
        
        await _showVerificationDialog();
      } else {
        throw Exception('Error al enviar código de verificación');
      }
    } catch (e) {
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
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          children: [
            const SizedBox(height: 8),
            const Text(
              '¡Registra tu salón\nahora mismo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            // Banda promo estilo píldora
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: _primaryOrange.withOpacity(0.7),
                  width: 1.8,
                ),
              ),
              child: const Center(
                child: Text(
                  '0% de comisión durante los primeros 30 días',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _primaryOrange,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionTitle('Nombre del salón *'),
            _buildTextField(
              _salonNameController,
              'Ej: Salón La Belleza',
              Icons.store_outlined,
            ),
            const SizedBox(height: 18),

            _buildSectionTitle('Email de la cuenta del salón *'),
            _buildTextField(
              _emailController,
              'ejemplo@email.com',
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 18),

            _buildSectionTitle('Contraseña para la cuenta del salón *'),
            _buildTextField(
              _passwordController,
              'Mínimo 6 caracteres',
              Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 18),

            _buildSectionTitle('Teléfono del salón *'),
            _buildTextField(
              _salonPhoneController,
              '+504...',
              Icons.phone_in_talk_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 18),

            _buildSectionTitle('RTN del salón *'),
            _buildTextField(
              _rtnController,
              '14 dígitos',
              Icons.business_outlined,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text(
                      'Siguiente: Añadir Dirección',
                      style: TextStyle(
                        fontSize: 18,
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            Center(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 14, color: _textSecondary),
                  children: [
                    TextSpan(text: '¿Eres estilista independiente? '),
                    TextSpan(
                      text: 'Regístrate aquí.',
                      style: TextStyle(
                        color: _primaryOrange,
                        fontWeight: FontWeight.bold,
                      ),
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
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: _textPrimary,
        ),
      ),
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
      maxLength: controller == _rtnController ? 14 : null,
      style: const TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.grey.shade300)
            : null,
        suffixIcon: hasSuffix
            ? Icon(Icons.search, color: Colors.grey.shade300)
            : null,
        filled: true,
        fillColor: _fieldColor,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade700, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade700, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primaryOrange, width: 1.2),
        ),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es requerido';
        }
        if (controller == _rtnController &&
            value != null &&
            value.length != 14) {
          return 'El RTN debe tener 14 dígitos';
        }
        return null;
      },
    );
  }
}