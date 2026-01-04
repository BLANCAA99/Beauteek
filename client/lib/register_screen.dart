import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'theme/app_theme.dart';
import 'setup_location_page.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _verificationCodeController = TextEditingController();
  String? _selectedGender;
  String errorMsg = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  late AnimationController _toastController;
  OverlayEntry? _toastEntry;

  @override
  void initState() {
    super.initState();
    _toastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _toastController.dispose();
    _dobController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  // --- Método para mostrar un toast animado verde ---
  Future<void> _showSuccessToast(String text) async {
    final curved = CurvedAnimation(
      parent: _toastController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _toastEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 40,
        right: 16,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0), // entra desde la derecha
            end: Offset.zero,
          ).animate(curved),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_toastEntry!);
    await _toastController.forward();
    await Future.delayed(const Duration(milliseconds: 1200));
    await _toastController.reverse();
    _toastEntry?.remove();
  }

  // Mostrar diálogo de verificación de email
  Future<void> showVerificationDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.email, color: AppTheme.primaryOrange),
                  SizedBox(width: 12),
                  Text(
                    'Verifica tu correo',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hemos enviado un código de 6 dígitos a:',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emailController.text.trim(),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _verificationCodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyLarge.copyWith(
                        letterSpacing: 8,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: '000000',
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
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
                    setState(() => _isLoading = false);
                  },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_verificationCodeController.text.trim().length != 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingresa el código de 6 dígitos'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      final response = await http.post(
                        Uri.parse('$apiBaseUrl/api/users/verify-code'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'email': emailController.text.trim(),
                          'code': _verificationCodeController.text.trim(),
                        }),
                      );

                      if (response.statusCode == 200) {
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        await completeRegistration();
                      } else {
                        final error = json.decode(response.body);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error['error'] ?? 'Código incorrecto'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error de conexión'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                  ),
                  child: const Text(
                    'Verificar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Completar registro después de verificar el código
  Future<void> completeRegistration() async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = credential.user;
      if (user == null) {
        setState(() => errorMsg = 'No se pudo obtener el usuario.');
        return;
      }

      final url = Uri.parse('$apiBaseUrl/api/users');
      final body = {
        'uid': user.uid,
        'nombre_completo': nameController.text.trim(),
        'email': emailController.text.trim(),
        'fecha_nacimiento': _dobController.text.trim(),
        'genero': _selectedGender,
        'telefono': 'pendiente',
        'rol': 'cliente',
        'foto_url': 'https://example.com/no_aplica.jpg',
        'estado': 'activo',
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        setState(() {
          errorMsg = '';
          _isLoading = false;
        });

        await _showSuccessToast('Registro exitoso');
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupLocationPage()),
        );
      } else {
        if (!mounted) return;
        setState(() {
          errorMsg = 'Error al guardar usuario en la base de datos.';
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'email-already-in-use') {
          errorMsg = 'Este correo ya está registrado. Por favor, usa otro correo o inicia sesión.';
        } else {
          errorMsg = e.message ?? 'No se pudo registrar. Verifica tus datos.';
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = 'Error inesperado. Intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  // Método principal de registro - Valida y envía código
  Future<void> register() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmController.text.isEmpty ||
        _dobController.text.isEmpty ||
        _selectedGender == null) {
      setState(() => errorMsg = 'Todos los campos son requeridos');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text.trim())) {
      setState(() => errorMsg = 'Correo electrónico inválido');
      return;
    }

    if (passwordController.text.length < 6) {
      setState(() => errorMsg = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }

    if (passwordController.text != confirmController.text) {
      setState(() => errorMsg = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      errorMsg = '';
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/users/send-verification-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': emailController.text.trim()}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _showSuccessToast('Código enviado a tu correo');
        if (!mounted) return;
        await showVerificationDialog();
      } else {
        final error = json.decode(response.body);
        setState(() {
          errorMsg = error['error'] ?? 'Error al enviar código';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = 'Error de conexión';
        _isLoading = false;
      });
    }
  }

  // ---------- UI REDISEÑADA ----------
  @override
  Widget build(BuildContext context) {
    BoxDecoration fieldDecoration(BuildContext context) {
      return BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1.2,
        ),
      );
    }

    TextStyle labelStyle = AppTheme.bodyLarge.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Crear Cuenta',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Nombre completo
                Text('Nombre completo', style: labelStyle),
                const SizedBox(height: 8),
                Container(
                  decoration: fieldDecoration(context),
                  child: TextField(
                    controller: nameController,
                    style: AppTheme.bodyLarge,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Ingresa tu nombre completo',
                    ).copyWith(
                      border: InputBorder.none,
                      prefixIcon: null,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Correo
                Text('Correo electrónico', style: labelStyle),
                const SizedBox(height: 8),
                Container(
                  decoration: fieldDecoration(context),
                  child: TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTheme.bodyLarge,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'tu.correo@ejemplo.com',
                    ).copyWith(
                      border: InputBorder.none,
                      prefixIcon: null,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Contraseña
                Text('Contraseña', style: labelStyle),
                const SizedBox(height: 8),
                Container(
                  decoration: fieldDecoration(context),
                  child: TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    style: AppTheme.bodyLarge,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Crea una contraseña segura',
                    ).copyWith(
                      border: InputBorder.none,
                      prefixIcon: null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Confirmar contraseña
                Text('Confirmar contraseña', style: labelStyle),
                const SizedBox(height: 8),
                Container(
                  decoration: fieldDecoration(context),
                  child: TextField(
                    controller: confirmController,
                    obscureText: _obscureConfirmPassword,
                    style: AppTheme.bodyLarge,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Repite tu contraseña',
                    ).copyWith(
                      border: InputBorder.none,
                      prefixIcon: null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword =
                                !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Fecha de nacimiento
                Text('Fecha de nacimiento', style: labelStyle),
                const SizedBox(height: 8),
                Container(
                  decoration: fieldDecoration(context),
                  child: TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    style: AppTheme.bodyLarge,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'DD/MM/AAAA',
                    ).copyWith(
                      border: InputBorder.none,
                      prefixIcon: null,
                      suffixIcon: const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    cursorColor: AppTheme.primaryOrange,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now()
                            .subtract(const Duration(days: 365 * 18)),
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppTheme.primaryOrange,
                                surface: AppTheme.cardBackground,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        setState(() {
                          // Puedes formatear a DD/MM/AAAA si quieres más adelante
                          _dobController.text =
                              '${pickedDate.day.toString().padLeft(2, '0')}/'
                              '${pickedDate.month.toString().padLeft(2, '0')}/'
                              '${pickedDate.year}';
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // Género (botones estilo pill)
                Text('Género', style: labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _GeneroButton(
                        label: 'Masculino',
                        seleccionado: _selectedGender == 'Masculino',
                        onTap: () {
                          setState(() {
                            _selectedGender = 'Masculino';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GeneroButton(
                        label: 'Femenino',
                        seleccionado: _selectedGender == 'Femenino',
                        onTap: () {
                          setState(() {
                            _selectedGender = 'Femenino';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Error
                if (errorMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg,
                              style: AppTheme.bodyMedium
                                  .copyWith(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Texto términos
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                              text: 'Al registrarte, aceptas nuestros '),
                          TextSpan(
                            text: 'Términos',
                            style: TextStyle(
                              color: AppTheme.primaryOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' y '),
                          TextSpan(
                            text: 'Política de Privacidad.',
                            style: TextStyle(
                              color: AppTheme.primaryOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Botón principal con degradado y sombra
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryOrange.withOpacity(0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Registrarse',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Enlace iniciar sesión
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '¿Ya tienes una cuenta? ',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Inicia sesión',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón pill para seleccionar género (diseño local, lógica intacta)
class _GeneroButton extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _GeneroButton({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: seleccionado
              ? Colors.white.withOpacity(0.08)
              : Colors.transparent,
          border: Border.all(
            color: seleccionado
                ? AppTheme.primaryOrange
                : Colors.white.withOpacity(0.25),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: seleccionado ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}