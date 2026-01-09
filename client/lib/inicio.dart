import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'inicio_cliente.dart';
import 'inicio_salon.dart';
import 'theme/app_theme.dart';

/// Router principal que decide qué pantalla de inicio mostrar según el rol del usuario
class InicioPage extends StatefulWidget {
  const InicioPage({Key? key}) : super(key: key);

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  bool _isLoading = true;
  String? _rolUsuario;

  @override
  void initState() {
    super.initState();
    _obtenerRolUsuario();
  }

  Future<void> _obtenerRolUsuario() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        _navegarSegunRol('cliente');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/users/uid/$uid');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Timeout al obtener datos del usuario');
        },
      );
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body) as Map<String, dynamic>;
        final rol = userData['rol'] as String?;
        
        if (!mounted) return;
        _navegarSegunRol(rol ?? 'cliente');
      } else {
        if (!mounted) return;
        _navegarSegunRol('cliente');
      }
    } catch (e) {
      if (!mounted) return;
      _navegarSegunRol('cliente');
    }
  }

  void _navegarSegunRol(String rol) {
    
    if (rol == 'salon') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const InicioSalonPage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const InicioClientePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Siempre mostrar el spinner mientras se determina el rol
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/Beauteeklogin.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: AppTheme.primaryOrange,
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando...',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
