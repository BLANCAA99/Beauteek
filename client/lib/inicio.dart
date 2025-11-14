import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'api_constants.dart';
import 'profile_menu.dart';
import 'search_page.dart';
import 'calendar_page.dart';
import 'salon_profile_page.dart';
import 'estadisticas_salon_page.dart';
import 'review_screen.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({Key? key}) : super(key: key);

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _salonesDestacados = [];
  List<Map<String, dynamic>> _salonesFiltrados = [];
  String? _categoriaSeleccionada;
  String _textoBusqueda = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isBuscando = false;
  double? _userLat;
  double? _userLng;
  String? _rolUsuario;
  String? _uidUsuario;
  String? _nombreSalon;
  String? _logoSalon;

  final categorias = [
    {"nombre": "Coloración", "color": 0xFFE6D9F2}, // Lavanda pastel
    {"nombre": "Corte", "color": 0xFFFFDFE6}, // Rosa pastel
    {"nombre": "Depilación", "color": 0xFFD4E6F1}, // Azul pastel
    {"nombre": "Facial", "color": 0xFFD5F4E6}, // Verde menta pastel
    {"nombre": "Maquillaje", "color": 0xFFFFE4D6}, // Durazno pastel
    {"nombre": "Masajes", "color": 0xFFFFFACD}, // Amarillo pastel
    {"nombre": "Tratamientos", "color": 0xFFD6EAF8}, // Azul cielo pastel
    {"nombre": "Uñas", "color": 0xFFF5E6D3}, // Beige pastel
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    await _obtenerDatosUsuario();
    
    if (_rolUsuario == 'cliente') {
      await _cargarSalonesDestacados();
      await _verificarCitasFinalizadas(); // ✅ NUEVO
    } else if (_rolUsuario == 'salon') {
      await _cargarDatosSalon();
      setState(() => _isLoading = false);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _obtenerDatosUsuario() async {
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
      print('🔍 Obteniendo usuario: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ Timeout obteniendo usuario');
          throw Exception('Timeout al obtener datos del usuario');
        },
      );

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final userData = json.decode(response.body) as Map<String, dynamic>;
        
        print('👤 Datos del usuario obtenidos');
        print('👔 Rol detectado: ${userData['rol']}');
        
        if (!mounted) return;
        
        setState(() {
          _uidUsuario = uid;
          _rolUsuario = userData['rol'];
        });
        
        if (_rolUsuario == 'cliente') {
          final ubicacion = userData['ubicacion'];
          double? lat, lng;
          
          if (ubicacion is Map) {
            lat = (ubicacion['_latitude'] ?? ubicacion['latitude'])?.toDouble();
            lng = (ubicacion['_longitude'] ?? ubicacion['longitude'])?.toDouble();
          } else if (ubicacion is List && ubicacion.length >= 2) {
            lat = (ubicacion[0] as num?)?.toDouble();
            lng = (ubicacion[1] as num?)?.toDouble();
          }
          
          if (!mounted) return;
          
          if (lat == null || lng == null) {
            print('⚠️ Cliente sin ubicación válida');
            setState(() {
              _userLat = null;
              _userLng = null;
            });
          } else {
            setState(() {
              _userLat = lat;
              _userLng = lng;
            });
            print('✅ Ubicación: Lat=$_userLat, Lng=$_userLng');
          }
        }
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        if (!mounted) return;
        setState(() {
          _rolUsuario = 'cliente';
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

  Future<void> _cargarSalonesDestacados() async {
    try {
      if (_rolUsuario != 'cliente') {
        print('⚠️ Usuario no es cliente');
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      // ✅ CAMBIO: Permitir continuar sin ubicación
      if (_userLat == null || _userLng == null) {
        print('⚠️ Usuario sin ubicación, mostrando categorías sin salones');
        if (!mounted) return;
        setState(() {
          _salonesDestacados = [];
          _salonesFiltrados = [];
          _isLoading = false;
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      
      final url = Uri.parse(
        '$apiBaseUrl/comercios/cerca?lat=$_userLat&lng=$_userLng&radio=10'
      );
      
      print('🔍 Buscando comercios cerca de ($_userLat, $_userLng) - radio: 10 km');
      print('📍 URL completa: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 15)); // ✅ CAMBIO: Timeout más largo

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> saloneData = json.decode(response.body);
        
        print('📊 Salones encontrados: ${saloneData.length}');
        
        if (saloneData.isNotEmpty) {
          print('📋 Ejemplo de salón: ${saloneData[0]}');
          print('   📍 Ubicación: ${saloneData[0]['ubicacion']}');
          print('   📦 Servicios: ${saloneData[0]['servicios']?.length ?? 0}');
        }
        
        if (!mounted) return; // ✅ CAMBIO: Verificar mounted
        
        setState(() {
          _salonesDestacados = List<Map<String, dynamic>>.from(
            saloneData.map((s) => s as Map<String, dynamic>)
          );
          _salonesFiltrados = _salonesDestacados;
          _isLoading = false;
        });

        print('✅ ${_salonesDestacados.length} salones cargados');
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        if (!mounted) return;
        setState(() {
          _salonesDestacados = [];
          _salonesFiltrados = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error: $e');
      if (!mounted) return; // ✅ CAMBIO: Verificar mounted
      setState(() {
        _salonesDestacados = [];
        _salonesFiltrados = [];
        _isLoading = false;
      });
    }
  }
  // ✅ CAMBIO: Función para normalizar texto (quitar tildes y convertir a minúsculas)
  String _normalizarTexto(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  // ✅ CAMBIO: Filtrar por servicios en lugar de categorías
  void _filtrarPorCategoria(String categoria) {
    _searchController.clear();
    _textoBusqueda = '';
    
    setState(() {
      _categoriaSeleccionada = categoria;
      _isBuscando = false;
      
      if (categoria == 'Todos') {
        _salonesFiltrados = _salonesDestacados;
        _categoriaSeleccionada = null;
      } else {
        // ✅ CAMBIO: Normalizar la categoría para búsqueda
        final categoriaNormalizada = _normalizarTexto(categoria);
        
        _salonesFiltrados = _salonesDestacados.where((salon) {
          final servicios = salon['servicios'] as List<dynamic>?;
          
          if (servicios != null) {
            return servicios.any((servicio) {
              // ✅ CAMBIO: Normalizar ambos lados de la comparación
              final categoriaId = servicio['categoria_id'] as String?;
              if (categoriaId == null) return false;
              
              final categoriaIdNormalizada = _normalizarTexto(categoriaId);
              return categoriaIdNormalizada == categoriaNormalizada;
            });
          }
          return false;
        }).toList();
        
        print('🔍 Filtrados por $categoria (normalizado: $categoriaNormalizada): ${_salonesFiltrados.length} salones');
        
        if (_salonesFiltrados.isEmpty) {
          print('⚠️ No se encontraron salones con categoría: $categoria');
          print('📊 Salones disponibles y sus servicios:');
          for (var salon in _salonesDestacados.take(3)) {
            final servicios = salon['servicios'] as List<dynamic>?;
            if (servicios != null) {
              print('  - ${salon['nombre']}: ${servicios.map((s) => '${s['categoria_id']} (normalizado: ${_normalizarTexto(s['categoria_id'] ?? '')})').toList()}');
            } else {
              print('  - ${salon['nombre']}: sin servicios');
            }
          }
        }
      }
    });
  }

  Future<void> _cargarDatosSalon() async {
    try {
      if (_uidUsuario == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      
      // Buscar comercios del usuario
      final url = Uri.parse('$apiBaseUrl/comercios');
      
      print('🏢 Buscando comercios del salón: $_uidUsuario');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      print('📥 Status: ${response.statusCode}');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> comercios = json.decode(response.body);
        
        // Buscar el comercio que pertenece a este usuario
        final miComercio = comercios.firstWhere(
          (c) => c['uid_negocio'] == _uidUsuario,
          orElse: () => null,
        );

        if (miComercio != null) {
          setState(() {
            _nombreSalon = miComercio['nombre'] ?? 'Mi Salón';
            _logoSalon = miComercio['foto_url'];
          });
          print('✅ Datos del salón cargados: $_nombreSalon');
        } else {
          print('⚠️ No se encontró comercio para este usuario');
          setState(() {
            _nombreSalon = 'Mi Salón';
          });
        }
      }
    } catch (e) {
      print('❌ Error cargando datos del salón: $e');
      setState(() {
        _nombreSalon = 'Mi Salón';
      });
    }
  }

  // ✅ NUEVO: Obtener saludo dinámico según la hora
  String _obtenerSaludo() {
    final hora = DateTime.now().hour;
    
    if (hora >= 0 && hora < 12) {
      return 'Buenos días';
    } else if (hora >= 12 && hora < 19) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  // ✅ NUEVO: Formatear fecha y hora
  String _obtenerFechaHoraActual() {
    final now = DateTime.now();
    final dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    final meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    
    final dia = dias[now.weekday % 7];
    final mes = meses[now.month - 1];
    final hora = now.hour.toString().padLeft(2, '0');
    final minuto = now.minute.toString().padLeft(2, '0');
    
    return '$dia, ${now.day} de $mes • $hora:$minuto';
  }

  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const double radioTierra = 6371;
    final dLat = _gradosARadianes(lat2 - lat1);
    final dLon = _gradosARadianes(lon2 - lon1);
    
    final a = 
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_gradosARadianes(lat1)) * cos(_gradosARadianes(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * asin(sqrt(a));
    return radioTierra * c;
  }

  double _gradosARadianes(double grados) {
    return grados * pi / 180;
  }

  // ✅ NUEVO: Verificar si hay citas finalizadas sin reseña
  Future<void> _verificarCitasFinalizadas() async {
    try {
      if (_uidUsuario == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      // ✅ Obtener todas las citas del usuario desde la API
      final citasUrl = Uri.parse('$apiBaseUrl/citas/usuario/$_uidUsuario');
      print('🔍 Verificando citas completadas para reseña: $citasUrl');
      
      final citasResponse = await http.get(
        citasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (citasResponse.statusCode == 404) {
        print('ℹ️ No hay citas para este usuario');
        return;
      }

      if (citasResponse.statusCode != 200) {
        print('⚠️ Error obteniendo citas: ${citasResponse.statusCode}');
        return;
      }

      final List<dynamic> citasData = json.decode(citasResponse.body);
      
      // Filtrar solo citas completadas
      final citasCompletadas = citasData.where((cita) => 
        cita['estado'] == 'completada'
      ).toList();
      
      if (citasCompletadas.isEmpty) {
        print('ℹ️ No hay citas completadas');
        return;
      }

      print('📋 Encontradas ${citasCompletadas.length} citas completadas');

      // Verificar cada cita si tiene reseña usando la API
      for (var cita in citasCompletadas) {
        final citaId = cita['id'];
        
        if (citaId == null) continue;

        // Verificar si existe reseña para esta cita
        final resenasUrl = Uri.parse('$apiBaseUrl/api/resenas?cita_id=$citaId');
        print('🔍 Verificando reseña para cita $citaId: $resenasUrl');
        
        final resenasResponse = await http.get(
          resenasUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );

        if (resenasResponse.statusCode == 200) {
          final List<dynamic> resenasData = json.decode(resenasResponse.body);
          
          print('📊 Reseñas encontradas para cita $citaId: ${resenasData.length}');
          
          // Si no tiene reseña, mostrar modal
          if (resenasData.isEmpty) {
            if (!mounted) return;
            
            print('✨ Mostrando modal de reseña para cita $citaId');
            await Future.delayed(const Duration(milliseconds: 500));
            
            _mostrarModalResena({
              'id': citaId,
              'comercio_id': cita['comercio_id'],
              'servicio_id': cita['servicio_id'],
              'servicio_nombre': cita['servicio_nombre'],
            });
            
            break; // Solo mostrar un modal a la vez
          }
        } else {
          print('⚠️ Error verificando reseñas: ${resenasResponse.statusCode}');
        }
      }
    } catch (e) {
      print('❌ Error verificando citas finalizadas: $e');
    }
  }

  // ✅ NUEVO: Modal para dejar reseña
  void _mostrarModalResena(Map<String, dynamic> cita) async {
    String salonName = 'Salón de belleza';
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && cita['comercio_id'] != null) {
        final idToken = await user.getIdToken();
        final comercioUrl = Uri.parse('$apiBaseUrl/comercios/${cita['comercio_id']}');
        final comercioResponse = await http.get(
          comercioUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );
        
        if (comercioResponse.statusCode == 200) {
          final comercioData = json.decode(comercioResponse.body);
          salonName = comercioData['nombre'] ?? salonName;
        }
      }
    } catch (e) {
      print('Error obteniendo nombre del salón: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEA963A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.celebration,
                color: Color(0xFFEA963A),
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¡Gracias por tu visita!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esperamos que hayas disfrutado tu experiencia.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          salonName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.design_services, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cita['servicio_nombre'] ?? 'Servicio',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¿Te gustaría compartir tu opinión sobre el servicio recibido?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu reseña nos ayuda a mejorar y ayuda a otros clientes a tomar decisiones.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Ahora no',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(
                    citaId: cita['id'],
                    comercioId: cita['comercio_id'],
                    salonName: salonName,
                    servicioId: cita['servicio_id'],
                  ),
                ),
              ).then((_) {
                // Después de dejar la reseña, recargar para no mostrar de nuevo
                _verificarCitasFinalizadas();
              });
            },
            icon: const Icon(Icons.star, color: Colors.white),
            label: const Text(
              'Dejar reseña',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA963A),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Buscar salones usando las APIs
  void _buscarSalones(String texto) {
    setState(() {
      _textoBusqueda = texto;
      _isBuscando = texto.isNotEmpty;
      _categoriaSeleccionada = null;
    });

    if (texto.isEmpty) {
      setState(() {
        _salonesFiltrados = _salonesDestacados;
      });
      return;
    }

    final textoNormalizado = _normalizarTexto(texto);

    setState(() {
      _salonesFiltrados = _salonesDestacados.where((salon) {
        // Buscar en nombre del salón
        final nombreNormalizado = _normalizarTexto(salon['nombre'] ?? '');
        if (nombreNormalizado.contains(textoNormalizado)) {
          return true;
        }

        // Buscar en servicios
        final servicios = salon['servicios'] as List<dynamic>?;
        if (servicios != null) {
          return servicios.any((servicio) {
            final nombreServicio = _normalizarTexto(servicio['nombre'] ?? '');
            final categoriaId = _normalizarTexto(servicio['categoria_id'] ?? '');
            
            return nombreServicio.contains(textoNormalizado) ||
                   categoriaId.contains(textoNormalizado);
          });
        }

        return false;
      }).toList();
    });

    print('🔍 Búsqueda "$texto": ${_salonesFiltrados.length} resultados');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'Beauteek',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Color(0xFF111418),
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.menu, size: 28),
                ],
              ),
            ),

            // ✅ Search Bar - SOLO visible para clientes
            if (_rolUsuario == 'cliente')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFF0F2F4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isBuscando ? Color(0xFFEA963A) : Color(0xFFE0E0E0),
                      width: _isBuscando ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: _isBuscando ? Color(0xFFEA963A) : Color(0xFF637588),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _buscarSalones,
                          decoration: InputDecoration(
                            hintText: 'Buscar salones o servicios',
                            hintStyle: TextStyle(color: Color(0xFF637588)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          style: TextStyle(
                            color: Color(0xFF111418),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (_textoBusqueda.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, color: Color(0xFF637588), size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _buscarSalones('');
                          },
                        ),
                    ],
                  ),
                ),
              ),

            // ✅ Pantalla personalizada para salones
            if (_rolUsuario == 'salon')
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: Color(0xFFEA963A)))
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20),
                            
                            // Logo del salón
                            Center(
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: _logoSalon == null
                                      ? LinearGradient(
                                          colors: [Color(0xFFEA963A), Color(0xFFFF6B9D)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  image: _logoSalon != null
                                      ? DecorationImage(
                                          image: NetworkImage(_logoSalon!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFEA963A).withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: _logoSalon == null
                                    ? Icon(Icons.store, size: 60, color: Colors.white)
                                    : null,
                              ),
                            ),
                            
                            SizedBox(height: 32),
                            
                            // Saludo dinámico
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    '${_obtenerSaludo()},',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Color(0xFF637588),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _nombreSalon ?? 'Mi Salón',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111418),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 24),
                            
                            // Fecha y hora actual
                            Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF0F2F4),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Color(0xFFE0E0E0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, color: Color(0xFFEA963A), size: 20),
                                    SizedBox(width: 12),
                                    Text(
                                      _obtenerFechaHoraActual(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF637588),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 48),
                          ],
                        ),
                      ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_rolUsuario == 'cliente') ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _isBuscando
                                      ? 'Resultados para "$_textoBusqueda"'
                                      : (_categoriaSeleccionada == null 
                                          ? 'Salones destacados cerca de ti'
                                          : 'Salones de $_categoriaSeleccionada'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: Color(0xFF111418),
                                  ),
                                ),
                              ),
                              if (_categoriaSeleccionada != null)
                                GestureDetector(
                                  onTap: () => _filtrarPorCategoria('Todos'),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFEA963A).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.clear, size: 16, color: Color(0xFFEA963A)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Limpiar',
                                          style: TextStyle(
                                            color: Color(0xFFEA963A),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Lista de salones destacados
                        if (_isLoading)
                          const SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(color: Color(0xFFEA963A)),
                            ),
                          )
                        else if (_salonesFiltrados.isEmpty)
                          Container(
                            height: 200,
                            margin: EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Color(0xFFE0E0E0)),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.store_outlined, size: 48, color: Color(0xFF637588)),
                                  SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Text(
                                      _isBuscando
                                          ? 'No encontramos salones con "$_textoBusqueda"'
                                          : (_categoriaSeleccionada == null 
                                              ? 'No hay salones cerca'
                                              : 'No hay salones con servicios de $_categoriaSeleccionada'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF637588),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (_categoriaSeleccionada != null || _isBuscando) ...[
                                    SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        _filtrarPorCategoria('Todos');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFFEA963A),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: Text(
                                        'Ver todos los salones',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _salonesFiltrados.length,
                              itemBuilder: (context, i) {
                                final salon = _salonesFiltrados[i];
                                final distancia = salon['distancia'] as double;
                                
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: GestureDetector(
                                    onTap: () {
                                      final comercioId = salon['id'];
                                      
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SalonProfilePage(
                                            comercioId: comercioId!,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 180,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                            child: SizedBox(
                                              width: 180,
                                              height: 130,
                                              child: salon['foto_url'] != null && salon['foto_url']!.isNotEmpty
                                                  ? Image.network(
                                                      salon['foto_url']!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) =>
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                colors: [Color(0xFFEA963A), Color(0xFFFF6B9D)],
                                                                begin: Alignment.topLeft,
                                                                end: Alignment.bottomRight,
                                                              ),
                                                            ),
                                                            child: Icon(
                                                              Icons.store,
                                                              size: 48,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                    )
                                                  : Container(
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [Color(0xFFEA963A), Color(0xFFFF6B9D)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons.store,
                                                        size: 48,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  salon['nombre']!,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: Color(0xFF111418),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.star, size: 14, color: Color(0xFFFFB800)),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      "${salon['calificacion'] ?? 4.5}",
                                                      style: const TextStyle(
                                                        color: Color(0xFF637588),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Icon(Icons.place, size: 14, color: Color(0xFF637588)),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      "${distancia.toStringAsFixed(1)} km",
                                                      style: const TextStyle(
                                                        color: Color(0xFF637588),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        SizedBox(height: 24),

                        // Categorías - SIEMPRE se muestran
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            'Servicios',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Color(0xFF111418),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.5, // ✅ Rectángulos horizontales
                            ),
                            itemCount: categorias.length,
                            itemBuilder: (context, index) {
                              final categoria = categorias[index];
                              final isSelected = _categoriaSeleccionada == categoria['nombre'];
                              
                              return GestureDetector(
                                onTap: () {
                                  _filtrarPorCategoria(categoria['nombre'] as String);
                                  
                                  Scrollable.ensureVisible(
                                    context,
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Color(categoria['color'] as int),
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected 
                                        ? Border.all(color: Color(0xFFEA963A), width: 2)
                                        : null,
                                    boxShadow: isSelected ? [
                                      BoxShadow(
                                        color: Color(0xFFEA963A).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ] : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      categoria['nombre'] as String,
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Color(0xFFF0F2F4),
          border: Border(
            top: BorderSide(color: Color(0xFFF0F2F4)),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home,
                label: 'Inicio',
                selected: true,
              ),
              if (_rolUsuario == 'salon')
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EstadisticasSalonPage(),
                      ),
                    );
                  },
                  child: const _NavItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Estadísticas',
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchPage(
                          mode: 'search',
                          userId: _uidUsuario,
                          userCountry: 'Honduras',
                        ),
                      ),
                    );
                  },
                  child: const _NavItem(
                    icon: Icons.search,
                    label: 'Buscar',
                  ),
                ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalendarPage(),
                    ),
                  );
                },
                child: const _NavItem(
                  icon: Icons.calendar_today,
                  label: 'Calendario',
                ),
              ),
              GestureDetector(
                onTap: () {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileMenuPage(uid: uid),
                    ),
                  );
                },
                child: const _NavItem(
                  icon: Icons.person_outline,
                  label: 'Perfil',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  const _NavItem({required this.icon, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Color(0xFF111418) : Color(0xFF637588);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
