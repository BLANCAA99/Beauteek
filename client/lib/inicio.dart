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
        print('⚠️ No hay usuario autenticado');
        if (!mounted) return;
        setState(() {
          _rolUsuario = 'cliente';
          _isLoading = false;
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/users/uid/$uid');
      print('🔍 Obteniendo rol del usuario: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('⏱️ Timeout obteniendo usuario');
          throw Exception('Timeout al obtener datos del usuario');
        },
      );

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final userData = json.decode(response.body) as Map<String, dynamic>;

        print('👔 Rol detectado: ${userData['rol']}');

        if (!mounted) return;

        setState(() {
          _rolUsuario = userData['rol'];
          _isLoading = false;
        });
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        if (!mounted) return;
        setState(() {
          _rolUsuario = 'cliente';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error: $e');
      if (!mounted) return;
      setState(() {
        _rolUsuario = 'cliente';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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

    // Redirigir según el rol del usuario
    if (_rolUsuario == 'salon') {
      return const InicioSalonPage();
    } else {
      return const InicioClientePage();
    }
  }
}
