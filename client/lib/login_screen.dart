import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'inicio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_constants.dart';
import 'setup_location_page.dart';
import 'theme/app_theme.dart';

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
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _loadingMessage = 'Iniciando sesión...';

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

  // ───────── Login con email/password ─────────
  Future<void> login() async {
    if (!mounted) return;
    setState(() {
      errorMsg = '';
      _isLoading = true;
      _loadingMessage = 'Verificando credenciales...';
    });

    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      if (!mounted) return;
      setState(() {
        errorMsg = 'Por favor, ingresa tu correo y contraseña.';
        _isLoading = false;
      });
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
        setState(() {
          errorMsg = 'No se pudo iniciar sesión. Intenta nuevamente.';
          _isLoading = false;
        });
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
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        if (!mounted) return;
        setState(() {
          errorMsg = 'Usuario no encontrado en la base de datos';
          _isLoading = false;
        });
        await FirebaseAuth.instance.signOut();
        return;
      }

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          errorMsg = 'Error del servidor: ${response.statusCode}';
          _isLoading = false;
        });
        return;
      }

      final userData = json.decode(response.body) as Map<String, dynamic>;
      final rol = userData['rol'] as String?;

      // 3) Verificar si el cliente tiene ubicación guardada en la colección ubicaciones
      bool tieneUbicacion = false;
      if (rol == 'cliente') {
        try {
          final ubicacionesUrl =
              Uri.parse('$apiBaseUrl/api/ubicaciones/usuario/${user.uid}');
          final ubicacionesResponse = await http.get(
            ubicacionesUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          ).timeout(const Duration(seconds: 10));

          if (ubicacionesResponse.statusCode == 200) {
            final ubicacionesData =
                json.decode(ubicacionesResponse.body) as List;
            tieneUbicacion = ubicacionesData.isNotEmpty;
          }
        } catch (e) {
          // Si falla la consulta, asumimos que no tiene ubicación
          tieneUbicacion = false;
        }
      }

      // 4) Mostrar mensaje de éxito y transición suave
      if (!mounted) return;

      setState(() {
        _loadingMessage = 'Credenciales correctas, iniciando sesión...';
      });

      // Pequeña pausa para que se vea el mensaje
      await Future.delayed(const Duration(milliseconds: 800));

      // (Opcional) también mostramos el toast
      await _showToast('¡Bienvenido!');

      if (!mounted) return;

      // 5) Redirigir: Clientes sin ubicación → SetupLocationPage, sino → InicioPage (router)
      if (rol == 'cliente' && !tieneUbicacion) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupLocationPage()),
        );
      } else {
        // InicioPage es un router que decide si mostrar InicioClientePage o InicioSalonPage
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

      setState(() {
        errorMsg = mensaje;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = 'Error inesperado. Por favor, intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  // ───────── Login/registro con Google ─────────
  Future<void> registerWithGoogle() async {
    setState(() {
      errorMsg = '';
      _isLoading = true;
      _loadingMessage = 'Conectando con Google...';
    });
    try {
      // 1. Cerrar sesión previa de Google (limpiar caché)
      await _googleSignIn.signOut();

      // 2. Iniciar sesión con Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Usuario canceló
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;
      setState(() => _loadingMessage = 'Autenticando con Firebase...');

      final googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      
      final user = userCred.user;
      
      if (user == null) {
        if (!mounted) return;
        setState(() {
          errorMsg =
              'No se pudo iniciar sesión con Google. Intenta nuevamente.';
          _isLoading = false;
        });
        return;
      }
      setState(() => _loadingMessage = 'Verificando usuario...');
      await Future.delayed(const Duration(milliseconds: 100));

      String? idToken; // Declarar aquí para usar fuera del try
      Map<String, dynamic>? userData;
      try {
      // Verificar si el usuario ya existe en tu API
      idToken = await user.getIdToken();
      
      // DELAY: Dar tiempo para procesar el token
      await Future.delayed(const Duration(milliseconds: 50));
      
      final checkUrl = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');
      
      final checkResponse = await http.get(
        checkUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      bool needsToCreateUser = false;

      if (checkResponse.statusCode == 404) {
        needsToCreateUser = true;
      } else if (checkResponse.statusCode == 200) {
        userData = json.decode(checkResponse.body) as Map<String, dynamic>;
      } else {
        throw Exception(
            'Error al verificar usuario: ${checkResponse.statusCode}');
      }
      if (needsToCreateUser) {
        
        if (!mounted) {
          } else {
            setState(() => _loadingMessage = 'Creando tu perfil...');
          }

        final displayName = user.displayName ?? 'Usuario Google';
        final email = user.email ?? '';
        final photoUrl = user.photoURL ?? '';

        final createUrl = Uri.parse('$apiBaseUrl/api/users');

        // IMPORTANTE: Usar el mismo formato que register_screen.dart
        final createPayload = {
          'uid': user.uid,
          'nombre_completo': displayName,
          'email': email,
          'telefono': 'pendiente',
          'rol': 'cliente',
          'foto_url': photoUrl.isNotEmpty
              ? photoUrl
              : 'https://example.com/no_aplica.jpg',
          'fecha_nacimiento': 'no_aplica',
          'genero': 'no_aplica',
          'estado': 'activo',
        };
        
        final freshToken = await user.getIdToken(true);
        
        // DELAY CRÍTICO: Dar tiempo antes del POST
        await Future.delayed(const Duration(milliseconds: 100));

          final createResponse = await http
              .post(
                createUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $freshToken',
                },
                body: jsonEncode(createPayload),
              )
              .timeout(const Duration(seconds: 20));

        if (createResponse.statusCode == 201 ||
            createResponse.statusCode == 200) {
          userData = json.decode(createResponse.body) as Map<String, dynamic>;
          
          // DELAY: Dar tiempo para que Firestore procese
          await Future.delayed(const Duration(milliseconds: 100));
        } else {
          if (!mounted) return;
          setState(() {
            errorMsg =
                'Error al crear tu perfil. Por favor, intenta nuevamente.';
            _isLoading = false;
          });

          // Cerrar sesión de Firebase para que pueda intentar de nuevo
          await FirebaseAuth.instance.signOut();
          return;
        }
      }
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          errorMsg = 'Error al procesar tu cuenta. Intenta de nuevo.';
          _isLoading = false;
        });
        await FirebaseAuth.instance.signOut();
        return;
      }

      final rol = userData?['rol'] as String?;

      // Verificar si el cliente tiene ubicación guardada en la colección ubicaciones
      bool tieneUbicacion = false;
      if (rol == 'cliente') {
        try {
          final ubicacionesUrl =
              Uri.parse('$apiBaseUrl/api/ubicaciones/usuario/${user.uid}');
          final ubicacionesResponse = await http.get(
            ubicacionesUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          ).timeout(const Duration(seconds: 5));
          
          if (ubicacionesResponse.statusCode == 200) {
            final ubicacionesData =
                json.decode(ubicacionesResponse.body) as List;
            tieneUbicacion = ubicacionesData.isNotEmpty;
          }
        } catch (e) {
          // Si falla la consulta, asumimos que no tiene ubicación
          tieneUbicacion = false;
        }
      }

      if (!mounted) return;
      await _showToast('¡Bienvenido!');

      if (!mounted) return;
      setState(() => _isLoading = false); 
      // Redirigir: clientes sin ubicación van a SetupLocationPage
      if (rol == 'cliente' && !tieneUbicacion) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupLocationPage()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const InicioPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String mensaje = 'Error al iniciar sesión con Google';

      switch (e.code) {
        case 'account-exists-with-different-credential':
          mensaje = 'Este correo ya está registrado con otro método. '
              'Inicia sesión con tu correo y contraseña.';
          break;
        case 'invalid-credential':
          mensaje = 'Credenciales de Google inválidas. Intenta nuevamente.';
          break;
        case 'operation-not-allowed':
          mensaje = 'El inicio de sesión con Google no está habilitado.';
          break;
        case 'user-disabled':
          mensaje = 'Esta cuenta ha sido deshabilitada.';
          break;
        default:
          mensaje = 'Error de autenticación: ${e.message}';
      }

      setState(() {
        errorMsg = mensaje;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = 'Error inesperado. Por favor, intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  // ───────── Restablecer contraseña ─────────
  Future<void> _resetPassword() async {
    final emailControllerDialog = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF4EC), // tono cremita
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Restablecer\ncontraseña',
              textAlign: TextAlign.center,
              style: AppTheme.heading3.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                fontSize: 13,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // Input redondeado tipo card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: emailControllerDialog,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Correo electrónico',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botones Cancelar / Enviar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    emailControllerDialog.dispose();
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    'Cancelar',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: AppTheme.primaryButtonStyle().copyWith(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    elevation: WidgetStateProperty.all(4),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: const Text(
                    'Enviar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result == true && emailControllerDialog.text.trim().isNotEmpty) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: emailControllerDialog.text.trim(),
        );

        emailControllerDialog.dispose();

        if (!mounted) return;

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } catch (e) {
        emailControllerDialog.dispose();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Error inesperado. Por favor, intenta de nuevo.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      emailControllerDialog.dispose();
    }
  }

  // ───────── Contenido principal de la pantalla ─────────
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),

        // Logo + nombre Beauteek (solo imagen, sin círculo naranja detrás)
        Center(
          child: Column(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Image.asset(
                  'assets/images/Beauteeklogin.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Beauteek',
                style: AppTheme.heading2.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // Título principal
        Text(
          'Inicia sesión en tu cuenta',
          style: AppTheme.heading1.copyWith(
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa tus credenciales para continuar',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),

        const SizedBox(height: 32),

        // Campo de correo
        Text(
          'Correo Electrónico',
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppTheme.cardDecoration(borderRadius: 18),
          child: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: AppTheme.bodyLarge,
            decoration: AppTheme.inputDecoration(
              hintText: 'tu@email.com',
              prefixIcon: Icons.mail_outline,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Campo de contraseña
        Text(
          'Contraseña',
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppTheme.cardDecoration(borderRadius: 18),
          child: TextField(
            controller: passwordController,
            obscureText: _obscurePassword,
            style: AppTheme.bodyLarge,
            decoration: AppTheme.inputDecoration(
              hintText: 'Ingresa tu contraseña',
              prefixIcon: Icons.lock_outline,
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

        // Mensaje de error
        if (errorMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMsg,
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Olvidé mi contraseña
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _resetPassword,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Olvidé mi contraseña',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryOrange,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Botón Iniciar Sesión
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: AppTheme.primaryButtonStyle().copyWith(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
            onPressed: _isLoading ? null : login,
            child: const Text(
              'Iniciar Sesión',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Divider con texto
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: AppTheme.textSecondary.withOpacity(0.3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'O inicia sesión con',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ), //
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: AppTheme.textSecondary.withOpacity(0.3),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Botones sociales circulares
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Google
            InkWell(
              onTap: _isLoading ? null : registerWithGoogle,
              borderRadius: BorderRadius.circular(40),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.darkBackground,
                  border: Border.all(
                    color: AppTheme.textSecondary.withOpacity(0.6),
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/Google.png',
                    width: 26,
                    height: 26,
                  ),
                ),
              ),
            ),
            // Facebook (solo UI)
            InkWell(
              onTap: () {
                // TODO: implementar login con Facebook
              },
              borderRadius: BorderRadius.circular(40),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.darkBackground,
                  border: Border.all(
                    color: AppTheme.textSecondary.withOpacity(0.6),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.facebook,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),

            // Apple (solo UI)
            InkWell(
              onTap: () {
                // TODO: implementar login con Apple
              },
              borderRadius: BorderRadius.circular(40),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.darkBackground,
                  border: Border.all(
                    color: AppTheme.textSecondary.withOpacity(0.6),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.apple,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Link a registro
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿No tienes una cuenta? ',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RegisterScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Regístrate',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // ───────── UI (solo diseño) ─────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildContent(),
            ),
          ),

          // Overlay de carga global
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
