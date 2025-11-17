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
import 'theme/app_theme.dart';

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
        const Duration(seconds: 8),
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
            lng =
                (ubicacion['_longitude'] ?? ubicacion['longitude'])?.toDouble();
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
          '$apiBaseUrl/comercios/cerca?lat=$_userLat&lng=$_userLng&radio=10');

      print(
          '🔍 Buscando comercios cerca de ($_userLat, $_userLng) - radio: 10 km');
      print('📍 URL completa: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 8));

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

        // ✅ Obtener foto del propietario y calificación promedio para cada salón
        final List<Map<String, dynamic>> salonesConFoto = [];
        for (var salon in saloneData) {
          final salonMap = salon as Map<String, dynamic>;
          final uidPropietario = salonMap['uid_negocio'] as String?;
          final comercioId = salonMap['id'] as String?;

          // Obtener foto del salon
          if (uidPropietario != null) {
            try {
              final propietarioUrl =
                  Uri.parse('$apiBaseUrl/api/users/uid/$uidPropietario');
              final propietarioResponse = await http.get(
                propietarioUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
              ).timeout(const Duration(seconds: 3));

              if (propietarioResponse.statusCode == 200) {
                final propietarioData = json.decode(propietarioResponse.body);
                final fotoSalon = propietarioData['foto_url'] as String?;

                if (fotoSalon != null && fotoSalon.isNotEmpty) {
                  salonMap['foto_url'] = fotoSalon;
                }
              }
            } catch (e) {
              print(
                  '⚠️ Error obteniendo foto del salón ${salonMap['nombre']}: $e');
            }
          }

          // Obtener calificación promedio de reseñas
          if (comercioId != null) {
            try {
              final resenasUrl =
                  Uri.parse('$apiBaseUrl/api/resenas?comercio_id=$comercioId');
              final resenasResponse = await http.get(
                resenasUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
              ).timeout(const Duration(seconds: 3));

              if (resenasResponse.statusCode == 200) {
                final List<dynamic> resenasData =
                    json.decode(resenasResponse.body);

                if (resenasData.isNotEmpty) {
                  double sumaCalificaciones = 0;
                  for (var resena in resenasData) {
                    sumaCalificaciones +=
                        (resena['calificacion'] as num?)?.toDouble() ?? 0;
                  }
                  salonMap['calificacion'] =
                      sumaCalificaciones / resenasData.length;
                }
              }
            } catch (e) {
              print(
                  '⚠️ Error obteniendo reseñas del salón ${salonMap['nombre']}: $e');
            }
          }

          salonesConFoto.add(salonMap);
        }

        if (!mounted) return; // ✅ CAMBIO: Verificar mounted

        setState(() {
          _salonesDestacados = salonesConFoto;
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

        print(
            '🔍 Filtrados por $categoria (normalizado: $categoriaNormalizada): ${_salonesFiltrados.length} salones');

        if (_salonesFiltrados.isEmpty) {
          print('⚠️ No se encontraron salones con categoría: $categoria');
          print('📊 Salones disponibles y sus servicios:');
          for (var salon in _salonesDestacados.take(3)) {
            final servicios = salon['servicios'] as List<dynamic>?;
            if (servicios != null) {
              print(
                  '  - ${salon['nombre']}: ${servicios.map((s) => '${s['categoria_id']} (normalizado: ${_normalizarTexto(s['categoria_id'] ?? '')})').toList()}');
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
      ).timeout(const Duration(seconds: 6));

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
    final dias = [
      'Domingo',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado'
    ];
    final meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];

    final dia = dias[now.weekday % 7];
    final mes = meses[now.month - 1];
    final hora = now.hour.toString().padLeft(2, '0');
    final minuto = now.minute.toString().padLeft(2, '0');

    return '$dia, ${now.day} de $mes • $hora:$minuto';
  }

  double _calcularDistancia(
      double lat1, double lon1, double lat2, double lon2) {
    const double radioTierra = 6371;
    final dLat = _gradosARadianes(lat2 - lat1);
    final dLon = _gradosARadianes(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_gradosARadianes(lat1)) *
            cos(_gradosARadianes(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

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
      ).timeout(const Duration(seconds: 5));

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
      final citasCompletadas =
          citasData.where((cita) => cita['estado'] == 'completada').toList();

      if (citasCompletadas.isEmpty) {
        print('ℹ️ No hay citas completadas');
        return;
      }

      print('📋 Encontradas ${citasCompletadas.length} citas completadas');

      // ✅ Solo verificar la primera cita completada (la más reciente)
      for (var cita in citasCompletadas.take(1)) {
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
        ).timeout(const Duration(seconds: 4));

        if (resenasResponse.statusCode == 200) {
          final List<dynamic> resenasData = json.decode(resenasResponse.body);

          print(
              '📊 Reseñas encontradas para cita $citaId: ${resenasData.length}');

          // Si no tiene reseña, mostrar modal
          if (resenasData.isEmpty) {
            if (!mounted) return;

            print('✨ Mostrando modal de reseña para cita $citaId');
            await Future.delayed(const Duration(milliseconds: 200));

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
        final comercioUrl =
            Uri.parse('$apiBaseUrl/comercios/${cita['comercio_id']}');
        final comercioResponse = await http.get(
          comercioUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        ).timeout(const Duration(seconds: 3));

        if (comercioResponse.statusCode == 200) {
          final comercioData = json.decode(comercioResponse.body);
          salonName = comercioData['nombre'] ?? salonName;
        }
      }
    } catch (e) {
      print('⚠️ No se pudo cargar nombre del salón (usando genérico): $e');
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
                      const Icon(Icons.design_services,
                          size: 16, color: Colors.grey),
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
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  // Obtener icono para cada categoría
  IconData _getCategoryIcon(String categoria) {
    switch (categoria) {
      case 'Coloración':
        return Icons.palette_outlined;
      case 'Corte':
        return Icons.content_cut_outlined;
      case 'Depilación':
        return Icons.spa_outlined;
      case 'Facial':
        return Icons.face_outlined;
      case 'Maquillaje':
        return Icons.brush_outlined;
      case 'Masajes':
        return Icons.back_hand_outlined;
      case 'Tratamientos':
        return Icons.health_and_safety_outlined;
      case 'Uñas':
        return Icons.touch_app_outlined;
      default:
        return Icons.category_outlined;
    }
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
            final categoriaId =
                _normalizarTexto(servicio['categoria_id'] ?? '');

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
    final nombreUsuario =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: usar este botón después
        },
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER tipo "Hola, Sofía" + campana
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ProfileMenuPage(uid: uid)),
                      );
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, $nombreUsuario',
                          style: AppTheme.heading3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Encuentra salones cerca de ti',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {
                          // TODO: abrir notificaciones
                        },
                        icon: const Icon(
                          Icons.notifications_none_outlined,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            // Search Bar - SOLO visible para clientes
            if (_rolUsuario == 'cliente')
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: AppTheme.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _buscarSalones,
                          style: AppTheme.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'Buscar salones, uñas, peinados...',
                            hintStyle: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_textoBusqueda.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _buscarSalones('');
                          },
                        ),
                    ],
                  ),
                ),
              ),

            // Pantalla personalizada para salones
            if (_rolUsuario == 'salon')
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryOrange))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            // Logo del salón
                            Center(
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: _logoSalon == null
                                      ? AppTheme.primaryGradient
                                      : null,
                                  image: _logoSalon != null
                                      ? DecorationImage(
                                          image: NetworkImage(_logoSalon!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryOrange
                                          .withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: _logoSalon == null
                                    ? const Icon(Icons.store,
                                        size: 60, color: Colors.white)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Saludo dinámico
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    '${_obtenerSaludo()},',
                                    style: AppTheme.heading3.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _nombreSalon ?? 'Mi Salón',
                                    style: AppTheme.heading1.copyWith(
                                      fontSize: 30,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Fecha y hora actual
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration:
                                    AppTheme.cardDecoration(borderRadius: 20),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        color: AppTheme.primaryOrange,
                                        size: 18),
                                    const SizedBox(width: 12),
                                    Text(
                                      _obtenerFechaHoraActual(),
                                      style: AppTheme.bodyLarge.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
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
                                  style: AppTheme.heading2,
                                ),
                              ),
                              if (_categoriaSeleccionada != null)
                                GestureDetector(
                                  onTap: () => _filtrarPorCategoria('Todos'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryOrange
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.clear,
                                            size: 16,
                                            color: AppTheme.primaryOrange),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Limpiar',
                                          style: AppTheme.caption.copyWith(
                                            color: AppTheme.primaryOrange,
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
                            height: 240,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.primaryOrange),
                            ),
                          )
                        else if (_salonesFiltrados.isEmpty)
                          Container(
                            height: 200,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration:
                                AppTheme.cardDecoration(borderRadius: 20),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.store_outlined,
                                      size: 48, color: AppTheme.textSecondary),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    child: Text(
                                      _isBuscando
                                          ? 'No encontramos salones con "$_textoBusqueda"'
                                          : (_categoriaSeleccionada == null
                                              ? 'No hay salones cerca'
                                              : 'No hay salones con servicios de $_categoriaSeleccionada'),
                                      textAlign: TextAlign.center,
                                      style: AppTheme.bodyLarge.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (_categoriaSeleccionada != null ||
                                      _isBuscando) ...[
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        _filtrarPorCategoria('Todos');
                                      },
                                      style: AppTheme.primaryButtonStyle(),
                                      child: const Text(
                                        'Ver todos los salones',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 240,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _salonesFiltrados.length,
                              itemBuilder: (context, i) {
                                final salon = _salonesFiltrados[i];
                                final distancia = salon['distancia'] as double;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 14),
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
                                      width: 220,
                                      decoration:
                                          AppTheme.elevatedCardDecoration(
                                              borderRadius: 20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(20)),
                                            child: SizedBox(
                                              width: 220,
                                              height: 140,
                                              child: salon['foto_url'] !=
                                                          null &&
                                                      salon['foto_url']!
                                                          .isNotEmpty
                                                  ? Image.network(
                                                      salon['foto_url']!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          Container(
                                                        decoration:
                                                            const BoxDecoration(
                                                          gradient: LinearGradient(
                                                              colors: [
                                                                AppTheme
                                                                    .primaryOrange,
                                                                Color(
                                                                    0xFFFF6B35)
                                                              ],
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight),
                                                        ),
                                                        child: const Icon(
                                                          Icons.store,
                                                          size: 48,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    )
                                                  : Container(
                                                      decoration:
                                                          const BoxDecoration(
                                                        gradient: AppTheme
                                                            .primaryGradient,
                                                      ),
                                                      child: const Icon(
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  salon['nombre']!,
                                                  style: AppTheme.bodyLarge
                                                      .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.star,
                                                        size: 14,
                                                        color:
                                                            Color(0xFFFFB800)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "${salon['calificacion'] ?? 4.5}",
                                                      style: AppTheme.caption
                                                          .copyWith(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.place,
                                                        size: 14,
                                                        color: AppTheme
                                                            .textSecondary),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "${distancia.toStringAsFixed(1)} km",
                                                      style: AppTheme.caption,
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

                        const SizedBox(height: 24),

                        // Categorías - SIEMPRE se muestran
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            'Explora por categoría',
                            style: AppTheme.heading2,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.0,
                            ),
                            itemCount: categorias.length,
                            itemBuilder: (context, index) {
                              final categoria = categorias[index];
                              final isSelected =
                                  _categoriaSeleccionada == categoria['nombre'];

                              return GestureDetector(
                                onTap: () {
                                  _filtrarPorCategoria(
                                      categoria['nombre'] as String);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primaryOrange
                                        : AppTheme.cardBackground,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primaryOrange
                                          : AppTheme.dividerColor,
                                      width: 1,
                                    ),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withOpacity(0.2)
                                              : AppTheme.primaryOrange
                                                  .withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(
                                              categoria['nombre'] as String),
                                          color: isSelected
                                              ? Colors.white
                                              : AppTheme.primaryOrange,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          categoria['nombre'] as String,
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontSize: 12,
                                            color: isSelected
                                                ? Colors.white
                                                : AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 80),
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
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          border: Border(
            top: BorderSide(color: AppTheme.dividerColor),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _NavItem(
                icon: Icons.home,
                label: 'Inicio',
                selected: true,
              ),
              GestureDetector(
                onTap: () {
                  if (_rolUsuario == 'salon') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EstadisticasSalonPage(),
                      ),
                    );
                  } else {
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
                  }
                },
                child: _NavItem(
                  icon: _rolUsuario == 'salon'
                      ? Icons.bar_chart_rounded
                      : Icons.search,
                  label: _rolUsuario == 'salon' ? 'Estadísticas' : 'Buscar',
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: navegar a pantalla de promociones
                },
                child: const _NavItem(
                  icon: Icons.local_offer_outlined,
                  label: 'Promociones',
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
  const _NavItem(
      {required this.icon, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primaryOrange : AppTheme.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.caption.copyWith(
            color: color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}