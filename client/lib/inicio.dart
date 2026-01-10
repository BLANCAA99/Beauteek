import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'inicio_cliente.dart';
import 'inicio_salon.dart';
import 'salon_address_page.dart';
import 'salon_services_page.dart';
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
        
        // Si es salón, verificar estado del comercio
        if (rol == 'salon') {
          final token = await user.getIdToken();
          if (token != null) {
            await _verificarEstadoComercioYNavegar(uid, token);
          } else {
            _navegarSegunRol('salon');
          }
        } else {
          _navegarSegunRol(rol ?? 'cliente');
        }
      } else {
        if (!mounted) return;
        _navegarSegunRol('cliente');
      }
    } catch (e) {
      if (!mounted) return;
      _navegarSegunRol('cliente');
    }
  }

  Future<void> _verificarEstadoComercioYNavegar(String uid, String idToken) async {
    try {
      // Buscar el comercio donde uid_negocio = uid del usuario salón
      final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
      final comerciosResponse = await http.get(
        comerciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (comerciosResponse.statusCode == 200) {
        final List<dynamic> comercios = json.decode(comerciosResponse.body);
        
        // Buscar comercio donde uid_negocio coincida
        final miComercio = comercios.firstWhere(
          (c) => c['uid_negocio'] == uid,
          orElse: () => null,
        );

        if (miComercio != null) {
          final estadoComercio = miComercio['estado'] as String?;
          final comercioId = miComercio['id_documento'] as String?;
          
          if (estadoComercio == 'activo') {
            // Comercio activo, ir a inicio
            _navegarSegunRol('salon');
          } else {
            // Comercio NO activo, redirigir al paso que falta
            _redirigirSegunEstadoComercio(estadoComercio, comercioId, uid);
          }
        } else {
          // No tiene comercio asociado (no debería pasar)
          _navegarSegunRol('salon');
        }
      } else {
        // Error al obtener comercios
        _navegarSegunRol('salon');
      }
    } catch (e) {
      // Error en verificación
      _navegarSegunRol('salon');
    }
  }

  void _redirigirSegunEstadoComercio(String? estado, String? comercioId, String uidNegocio) {
    if (comercioId == null) {
      _navegarSegunRol('salon');
      return;
    }

    switch (estado) {
      case 'paso1_completado':
        // Falta ubicación
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SalonAddressPage(
              comercioId: comercioId,
              uidNegocio: uidNegocio,
            ),
          ),
        );
        break;
        
      case 'paso2_completado':
      case 'paso3_completado':
        // Falta servicios y horarios
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SalonServicesPage(
              comercioId: comercioId,
              uidNegocio: uidNegocio,
            ),
          ),
        );
        break;
        
      default:
        // Estado desconocido o cualquier otro caso
        _navegarSegunRol('salon');
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
