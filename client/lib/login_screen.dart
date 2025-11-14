import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'inicio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'api_constants.dart';
import 'setup_location_page.dart'; // <-- AGREGAR IMPORT

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMsg = '';
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ───────── Toast animado (verde) ─────────
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
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _showToast(String text) async {
    _toastEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 40,
        right: 16,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _toastController,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
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

  // Log solo en debug
  void _d(String m) {
    if (kDebugMode) debugPrint(m);
  }

  // ───────── Login con email/password ─────────
  Future<void> login() async {
    if (!mounted) return; // ✅ Verificar mounted al inicio
    setState(() => errorMsg = '');

    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      if (!mounted) return;
      setState(() => errorMsg = 'Por favor, ingresa tu correo y contraseña.');
      return;
    }

    try {
      // 1) Firebase Auth
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final user = credential.user;
      if (user == null) {
        if (!mounted) return;
        setState(() => errorMsg = 'No se pudo iniciar sesión. Intenta nuevamente.');
        return;
      }

      // 2) Obtener datos del usuario desde tu API
      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 15)); // ✅ CAMBIO: 15s es suficiente

      if (response.statusCode == 404) {
        if (!mounted) return;
        setState(() => errorMsg = 'Usuario no encontrado en la base de datos');
        await FirebaseAuth.instance.signOut();
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Error al obtener usuario: ${response.statusCode}');
      }

      final userData = json.decode(response.body) as Map<String, dynamic>;
      final rol = userData['rol'] as String?;
      final ubicacion = userData['ubicacion'];

      if (!mounted) return; // ✅ Verificar mounted antes del toast
      await _showToast('¡Bienvenido!');
      if (!mounted) return; // ✅ Verificar mounted antes de navegar

      // 3) Redirigir según rol y ubicación
      if (rol == 'cliente' && ubicacion == null) {
        // Cliente sin ubicación -> SetupLocationPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupLocationPage()),
        );
      } else {
        // Usuario con ubicación o salón -> InicioPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const InicioPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String mensaje = 'Error al iniciar sesión';
      
      switch (e.code) {
        case 'user-not-found':
          mensaje = 'No existe una cuenta con este correo electrónico';
          break;
        case 'wrong-password':
          mensaje = 'La contraseña es incorrecta';
          break;
        case 'invalid-email':
          mensaje = 'El correo electrónico no es válido';
          break;
        case 'user-disabled':
          mensaje = 'Esta cuenta ha sido deshabilitada';
          break;
        case 'too-many-requests':
          mensaje = 'Demasiados intentos. Intenta más tarde';
          break;
        case 'invalid-credential':
          mensaje = 'Correo o contraseña incorrectos';
          break;
        default:
          mensaje = 'Correo o contraseña incorrectos';
      }
      
      setState(() => errorMsg = mensaje);
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMsg = 'Error inesperado. Por favor, intenta de nuevo.');
    }
  }

  // ───────── Login/registro con Google ─────────
  Future<void> registerWithGoogle() async {
    setState(() => errorMsg = '');
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // cancelado

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        setState(() => errorMsg = 'No se pudo iniciar sesión con Google. Intenta nuevamente.');
        return;
      }

      // Verificar si el usuario ya existe en tu API
      final idToken = await user.getIdToken();
      final checkUrl = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');
      
      final checkResponse = await http.get(
        checkUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      Map<String, dynamic>? userData;

      if (checkResponse.statusCode == 404) {
        // Usuario NO existe, crear perfil automáticamente
        print('🆕 Usuario nuevo con Google, creando perfil...');

        // Extraer nombre y apellido del displayName
        final displayName = user.displayName ?? '';
        final nameParts = displayName.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        // Crear usuario en el backend
        final createUrl = Uri.parse('$apiBaseUrl/api/users');
        final createPayload = {
          'uid': user.uid,
          'nombre_completo': displayName.isNotEmpty ? displayName : 'Usuario de Google',
          'email': user.email ?? '',
          'telefono': user.phoneNumber ?? '',
          'rol': 'cliente', // Por defecto es cliente
          'foto_url': user.photoURL ?? '',
          'fecha_creacion': DateTime.now().toIso8601String(),
        };

        print('📤 Creando usuario: ${json.encode(createPayload)}');

        final createResponse = await http.post(
          createUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: json.encode(createPayload),
        ).timeout(const Duration(seconds: 10));

        if (createResponse.statusCode == 201 || createResponse.statusCode == 200) {
          print('✅ Usuario creado exitosamente');
          userData = json.decode(createResponse.body) as Map<String, dynamic>;
        } else {
          throw Exception('Error al crear usuario: ${createResponse.statusCode} - ${createResponse.body}');
        }
      } else if (checkResponse.statusCode == 200) {
        // Usuario ya existe
        print('✅ Usuario existente encontrado');
        userData = json.decode(checkResponse.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error al verificar usuario: ${checkResponse.statusCode}');
      }

      // Verificar rol y ubicación
      final rol = userData?['rol'] as String?;
      final ubicacion = userData?['ubicacion'];

      await _showToast('¡Bienvenido!');
      if (!mounted) return;

      // Redirigir según rol y ubicación
      if (rol == 'cliente' && ubicacion == null) {
        // Cliente sin ubicación -> SetupLocationPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupLocationPage()),
        );
      } else {
        // Usuario con ubicación o salón -> InicioPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const InicioPage()),
        );
      }

    } catch (e) {
      print('❌ Error en registerWithGoogle: $e');
      setState(() => errorMsg = 'Error al iniciar sesión con Google. Intenta nuevamente.');
    }
  }

  // ───────── Restablecer contraseña ─────────
  Future<void> _resetPassword() async {
    final emailControllerDialog = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Restablecer contraseña',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailControllerDialog,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Correo electrónico',
                filled: true,
                fillColor: const Color(0xFFF3F1EE),
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
              emailControllerDialog.dispose();
              Navigator.of(context).pop(false);
            },
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA963A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && emailControllerDialog.text.trim().isNotEmpty) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: emailControllerDialog.text.trim(),
        );
        
        emailControllerDialog.dispose();
        
        if (!mounted) return;
        
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Correo enviado! Revisa tu bandeja de entrada.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      } on FirebaseAuthException catch (e) {
        emailControllerDialog.dispose();
        if (!mounted) return;
        
        String errorMessage = 'Error al enviar el correo';
        
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No existe una cuenta registrada con este correo';
            break;
          case 'invalid-email':
            errorMessage = 'El correo electrónico no es válido';
            break;
          case 'too-many-requests':
            errorMessage = 'Demasiados intentos. Intenta más tarde';
            break;
          default:
            errorMessage = 'No se pudo enviar el correo. Verifica tu conexión';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } catch (e) {
        emailControllerDialog.dispose();
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error inesperado. Por favor, intenta de nuevo.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      emailControllerDialog.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'Beauteek',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Bienvenido',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            hintText: 'Correo electrónico',
                            filled: true,
                            fillColor: const Color(0xFFF3F1EE),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            hintStyle: const TextStyle(color: Color(0xFF9B8C7B)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Contraseña',
                            filled: true,
                            fillColor: const Color(0xFFF3F1EE),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            hintStyle: const TextStyle(color: Color(0xFF9B8C7B)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (errorMsg.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              errorMsg,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _resetPassword, // Conectar función
                            child: const Text(
                              '¿Olvidaste tu contraseña?',
                              style: TextStyle(
                                color: Color(0xFF9B8C7B),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA963A),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: login,
                            child: const Text(
                              'Ingresar',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Image.asset(
                              'assets/images/Google.png',
                              width: 24,
                              height: 24,
                            ),
                            label: const Text(
                              "Registrarse con Google",
                              style: TextStyle(
                                color: Color(0xFFEA963A),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              side: const BorderSide(color: Color(0xFFEA963A), width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                            onPressed: registerWithGoogle,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                            child: const Text(
                              "Registrarse",
                              style: TextStyle(
                                color: Color(0xFFEA963A),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}