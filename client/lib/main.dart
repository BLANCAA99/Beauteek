import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'login_screen.dart';
import 'inicio.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print('Usando Firebase Auth en PRODUCCIÓN');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beauteek',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEA963A)),
        fontFamily: 'Montserrat',
      ),
      home: const SplashScreen(), // ✅ Cambiado aquí
    );
  }
}

// ✅ SplashScreen PRIMERO, luego AuthWrapper
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.7, end: 1.2).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    _controller.forward();

    // ✅ Espera 3 segundos y luego va a AuthWrapper
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/wallpaper.png',
          fit: BoxFit.cover,
        ),
        Center(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 120, 
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white, // ⬅️ fondo blanco dentro del marco
                         borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                       padding: const EdgeInsets.all(12),
                      child: FittedBox(
                        fit: BoxFit.cover,
                      child: Image.asset(
                        'assets/images/Beauteek.png',
                      ),
                     ),
                    ),
                   ),
                  ),
                  const SizedBox(height: 24),
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Image.asset(
                      'assets/images/titulobeauteek.png',
                      width: 180,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ✅ AuthWrapper DESPUÉS del splash
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData) {
          return const InicioPage();
        }
        
        return const LoginScreen();
      },
    );
  }
}