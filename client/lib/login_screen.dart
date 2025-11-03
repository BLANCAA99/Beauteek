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
    setState(() => errorMsg = '');

    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      setState(() => errorMsg = 'Ingresa correo y contraseña.');
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
        setState(() => errorMsg = 'No se pudo obtener el usuario.');
        return;
      }

      // OK
      await _showToast('¡Bienvenido!');
        if (!mounted) return;

        // 👇 Aquí lo redirigimos a la página de inicio
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => InicioPage()),
        );
    } on FirebaseAuthException catch (e) {
      setState(() => errorMsg = e.message ?? 'Correo o contraseña incorrectos');
    } catch (e) {
      setState(() => errorMsg = 'Error inesperado. Intenta de nuevo.');
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

      // 1) Iniciar sesión en Firebase con Google
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        setState(() => errorMsg = 'No se pudo obtener el usuario de Google.');
        return;
      }

      // 2) Verificar en tu colección usuarios por uid
      bool existsInDb = false;

      // 2a) (Opcional) Intentar tu API primero
      try {
        final url = Uri.parse(
          '$apiBaseUrl/api/users/uid/${user.uid}',
        );
        final resp = await http.get(url).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          existsInDb = true;
        }
      } catch (_) {}

      // 2b) Fallback Firestore
      if (!existsInDb) {
        final snap = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();
        existsInDb = snap.docs.isNotEmpty;
      }

      if (!existsInDb) {
        // Si no existe, podrías crear el doc llamando a tu API de registro
        // o crearlo directo en Firestore si tus reglas lo permiten.
        setState(() => errorMsg = 'Tu cuenta Google no está registrada.');
        await FirebaseAuth.instance.signOut();
        return;
      }

      await _showToast('¡Bienvenido!');
      if (!mounted) return;
      Navigator.of(context).pushReplacement( // <--- CAMBIADO A pushReplacement
        MaterialPageRoute(builder: (_) => InicioPage()),
      );

    } catch (e) {
      setState(() => errorMsg = 'Error de Google Sign-In');
    }
  }

  // ───────── Restablecer contraseña ─────────
  Future<void> _resetPassword() async {
    final emailControllerDialog = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // No cerrar al tocar afuera
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
              'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
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
        if (e.code == 'user-not-found') {
          errorMessage = 'No existe una cuenta con ese correo';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Correo electrónico inválido';
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
            content: const Text('Error inesperado. Intenta de nuevo.'),
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