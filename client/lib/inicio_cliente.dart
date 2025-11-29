import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'profile_menu.dart';
import 'search_page.dart';
import 'calendar_page.dart';
import 'salon_profile_page.dart';
import 'review_screen.dart';
import 'promociones_page.dart';
import 'notificaciones_page.dart';
import 'setup_location_page.dart';
import 'comparar_servicios_page.dart';
import 'theme/app_theme.dart';

class InicioClientePage extends StatefulWidget {
  const InicioClientePage({Key? key}) : super(key: key);

  @override
  State<InicioClientePage> createState() => _InicioClientePageState();
}

class _InicioClientePageState extends State<InicioClientePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _salonesDestacados = [];
  List<Map<String, dynamic>> _salonesFiltrados = [];
  List<Map<String, dynamic>> _promocionesActivas = [];
  String? _categoriaSeleccionada;
  String _textoBusqueda = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isBuscando = false;
  double? _userLat;
  double? _userLng;
  String? _uidUsuario;
  String _nombreUsuario = 'Usuario';
  String? _fotoUsuario;

  // Estadísticas personalizadas del cliente
  int _citasPendientes = 0;
  int _totalServicios = 0;
  int _salonesVisitados = 0;

  // Caché en memoria: uid_negocio -> foto_url
  final Map<String, String?> _cacheFotosSalones = {};

  final categorias = [
    {"nombre": "Coloración"},
    {"nombre": "Corte"},
    {"nombre": "Depilación"},
    {"nombre": "Facial"},
    {"nombre": "Maquillaje"},
    {"nombre": "Masajes"},
    {"nombre": "Tratamientos"},
    {"nombre": "Uñas"},
  ];

  @override
  void initState() {
    super.initState();
    _verificarUbicacionYCargar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _verificarUbicacionYCargar() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _cargarDatosIniciales();
        return;
      }

      final idToken = await user.getIdToken();
      final ubicacionUrl = Uri.parse(
          '$apiBaseUrl/api/ubicaciones/principal/${user.uid}?tipo=cliente');

      print('🔍 Verificando ubicación del cliente: $ubicacionUrl');

      final ubicacionResponse = await http.get(
        ubicacionUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 30));

      print('📍 Status ubicación: ${ubicacionResponse.statusCode}');
      print('📍 Body: ${ubicacionResponse.body}');

      final ubicacionPrincipal = ubicacionResponse.statusCode == 200
          ? json.decode(ubicacionResponse.body)
          : null;

      if (ubicacionPrincipal == null) {
        print(
            '⚠️ Cliente sin ubicación principal, redirigiendo a SetupLocationPage');
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupLocationPage()),
        );
        return;
      }

      print('✅ Cliente tiene ubicación principal configurada');
      _cargarDatosIniciales();
    } catch (e) {
      print('❌ Error verificando ubicación: $e');
      _cargarDatosIniciales(); // Intentar cargar de todos modos
    }
  }

  Future<void> _cargarDatosIniciales() async {
    await _obtenerDatosUsuario();
    await _cargarEstadisticasCliente();
    await _cargarSalonesDestacados();
    await _cargarPromocionesActivas();
    await _verificarCitasFinalizadas();

    _inicializarNotificaciones();
  }

  Future<void> _inicializarNotificaciones() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Permisos de notificaciones concedidos');

        final fcmToken = await messaging.getToken();
        if (fcmToken != null) {
          print('📱 FCM Token: $fcmToken');

          final idToken = await user.getIdToken(true);
          try {
            await http.put(
              Uri.parse('$apiBaseUrl/users/fcm-token'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: json.encode({
                'fcm_token': fcmToken,
                'platform': 'android',
              }),
            );
            print('✅ Token FCM guardado en servidor');
          } catch (e) {
            print('⚠️ Error guardando token FCM: $e');
          }
        }
      } else {
        print('⚠️ Permisos de notificaciones denegados');
      }
    } catch (e) {
      print('⚠️ Error inicializando notificaciones: $e');
    }
  }

  Future<void> _obtenerDatosUsuario() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        print('⚠️ No hay usuario autenticado');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/users/uid/$uid');
      print('🔍 Obteniendo usuario: $url');

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          )
          .timeout(
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
        final nombreCompleto =
            userData['nombre_completo'] ?? userData['displayName'] ?? 'Usuario';

        final primerNombre = nombreCompleto.toString().split(' ').first;

        if (!mounted) return;

        setState(() {
          _uidUsuario = uid;
          _nombreUsuario = primerNombre;
          _fotoUsuario = (userData['foto_url'] != null &&
                  userData['foto_url'].toString().isNotEmpty)
              ? userData['foto_url']
              : user.photoURL;
        });

        // Ubicación del cliente
        final idToken2 = await user.getIdToken();
        final ubicacionUrl =
            Uri.parse('$apiBaseUrl/api/ubicaciones/principal/$uid?tipo=cliente');
        final ubicacionResponse = await http.get(
          ubicacionUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken2',
          },
        ).timeout(const Duration(seconds: 30));

        final ubicacionData = ubicacionResponse.statusCode == 200
            ? json.decode(ubicacionResponse.body)
            : null;

        if (!mounted) return;

        if (ubicacionData == null) {
          print('⚠️ Cliente sin ubicación principal');
          setState(() {
            _userLat = null;
            _userLng = null;
          });
        } else {
          setState(() {
            _userLat = ubicacionData['lat'];
            _userLng = ubicacionData['lng'];
          });
          print(
              '✅ Ubicación desde colección ubicaciones: Lat=$_userLat, Lng=$_userLng');
        }
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Helper: trae (y cachea) la foto del salón según uid_negocio en colección usuarios
  Future<String?> _obtenerFotoSalonPorUid(
      String uidNegocio, String idToken) async {
    if (_cacheFotosSalones.containsKey(uidNegocio)) {
      return _cacheFotosSalones[uidNegocio];
    }

    try {
      final propietarioUrl =
          Uri.parse('$apiBaseUrl/api/users/uid/$uidNegocio');
      final propietarioResponse = await http.get(
        propietarioUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 4));

      if (propietarioResponse.statusCode == 200) {
        final propietarioData = json.decode(propietarioResponse.body);
        final fotoSalon = propietarioData['foto_url'] as String?;
        _cacheFotosSalones[uidNegocio] = fotoSalon;
        return fotoSalon;
      } else {
        print(
            '⚠️ Error HTTP obteniendo usuario $uidNegocio: ${propietarioResponse.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error obteniendo foto del salón (uid=$uidNegocio): $e');
    }

    _cacheFotosSalones[uidNegocio] = null;
    return null;
  }

  Future<void> _cargarSalonesDestacados() async {
  try {
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
      '$apiBaseUrl/comercios/cerca?lat=$_userLat&lng=$_userLng&radio=10',
    );

    print('🔍 Buscando comercios cerca de ($_userLat, $_userLng) - radio: 10 km');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
    ).timeout(const Duration(seconds: 8));

    print('📥 Response status (cerca): ${response.statusCode}');

    if (response.statusCode != 200) {
      print('❌ Error HTTP en /comercios/cerca: ${response.statusCode}');
      if (!mounted) return;
      setState(() {
        _salonesDestacados = [];
        _salonesFiltrados = [];
        _isLoading = false;
      });
      return;
    }

    final List<dynamic> saloneData = json.decode(response.body);
    print('📊 Salones encontrados: ${saloneData.length}');

    final List<Map<String, dynamic>> salonesConFoto = [];

    for (var salon in saloneData) {
      final salonMap = Map<String, dynamic>.from(salon);
      final comercioId = salonMap['id'] as String?;
      String? uidPropietario;

      print('➡️ Procesando comercioId: $comercioId');

      // 1️⃣ Traer detalle del comercio para obtener uid_negocio si no viene
      if (comercioId != null) {
        try {
          final detalleUrl = Uri.parse('$apiBaseUrl/comercios/$comercioId');
          final detalleResp = await http.get(
            detalleUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          ).timeout(const Duration(seconds: 5));

          print('   📄 Detalle comercio status: ${detalleResp.statusCode}');

          if (detalleResp.statusCode == 200) {
            final detalleData = json.decode(detalleResp.body);
            uidPropietario = detalleData['uid_negocio'] as String?;

            // Si del detalle ya viene una foto_url, la usamos también
            final fotoDesdeDetalle = detalleData['foto_url'] as String?;
            if (fotoDesdeDetalle != null && fotoDesdeDetalle.isNotEmpty) {
              salonMap['foto_url'] = fotoDesdeDetalle;
            }

            print('   ✅ uid_negocio desde detalle: $uidPropietario');
          }
        } catch (e) {
          print('⚠️ Error obteniendo detalle de comercio $comercioId: $e');
        }
      }

      // 2️⃣ Si tenemos uid_negocio, pedir foto al endpoint /api/users/uid/{uid}
      if (uidPropietario != null && uidPropietario.isNotEmpty && idToken != null) {
        final fotoSalon =
            await _obtenerFotoSalonPorUid(uidPropietario, idToken);
        print('   🖼️ fotoSalon obtenida para $uidPropietario: $fotoSalon');

        if (fotoSalon != null && fotoSalon.isNotEmpty) {
          salonMap['foto_url'] = fotoSalon;
        }
      }

      // 3️⃣ Calificación promedio desde reseñas
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
          print('⚠️ Error obteniendo reseñas del salón ${salonMap['nombre']}: $e');
        }
      }

      print('   ✅ salonMap final: $salonMap');
      salonesConFoto.add(salonMap);
    }

    if (!mounted) return;

    setState(() {
      _salonesDestacados = salonesConFoto;
      _salonesFiltrados = _salonesDestacados;
      _isLoading = false;
    });
    print('✅ ${_salonesDestacados.length} salones cargados (con posibles fotos)');
  } catch (e) {
    print('❌ Error _cargarSalonesDestacados: $e');
    if (!mounted) return;
    setState(() {
      _salonesDestacados = [];
      _salonesFiltrados = [];
      _isLoading = false;
    });
  }
}
  Future<void> _cargarPromocionesActivas() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/promociones');

      print('🎁 Cargando promociones activas');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        final now = DateTime.now();
        final promocionesActivas = data.where((promo) {
          if (promo['activo'] != true) return false;

          try {
            final fechaFin = DateTime.parse(promo['fecha_fin']);
            return fechaFin.isAfter(now);
          } catch (e) {
            return false;
          }
        }).toList();

        print(
            '✅ Promociones activas encontradas: ${promocionesActivas.length}');

        if (!mounted) return;

        setState(() {
          _promocionesActivas =
              promocionesActivas.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('❌ Error cargando promociones: $e');
    }
  }

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
        final categoriaNormalizada = _normalizarTexto(categoria);

        _salonesFiltrados = _salonesDestacados.where((salon) {
          final servicios = salon['servicios'] as List<dynamic>?;

          if (servicios != null) {
            return servicios.any((servicio) {
              final categoriaId = servicio['categoria_id'] as String?;
              if (categoriaId == null) return false;

              final categoriaIdNormalizada = _normalizarTexto(categoriaId);
              return categoriaIdNormalizada == categoriaNormalizada;
            });
          }
          return false;
        }).toList();

        print(
            '🔍 Filtrados por $categoria: ${_salonesFiltrados.length} salones');
      }
    });
  }

  Future<void> _cargarEstadisticasCliente() async {
    try {
      if (_uidUsuario == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      final citasUrl = Uri.parse('$apiBaseUrl/citas/usuario/$_uidUsuario');
      print('📊 Cargando estadísticas del cliente: $citasUrl');

      final citasResponse = await http.get(
        citasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (citasResponse.statusCode == 200) {
        final List<dynamic> citasData = json.decode(citasResponse.body);

        final ahora = DateTime.now();
        int pendientes = 0;
        Set<String> comerciosUnicos = {};

        for (var cita in citasData) {
          final estado = cita['estado'] as String?;

          if (estado == 'confirmada' || estado == 'pendiente') {
            try {
              final fechaStr = cita['fecha'] as String?;
              if (fechaStr != null) {
                final fechaCita = DateTime.parse(fechaStr);
                if (fechaCita.isAfter(ahora)) {
                  pendientes++;
                }
              }
            } catch (e) {
              print('⚠️ Error parseando fecha: $e');
            }
          }

          if (estado == 'completada') {
            final comercioId = cita['comercio_id'] as String?;
            if (comercioId != null) {
              comerciosUnicos.add(comercioId);
            }
          }
        }

        if (!mounted) return;

        setState(() {
          _citasPendientes = pendientes;
          _totalServicios = citasData.length;
          _salonesVisitados = comerciosUnicos.length;
        });

        print(
            '✅ Estadísticas: Pendientes=$_citasPendientes, Total=$_totalServicios, Salones=$_salonesVisitados');
      } else if (citasResponse.statusCode == 404) {
        print('ℹ️ Usuario sin citas registradas');
        if (!mounted) return;
        setState(() {
          _citasPendientes = 0;
          _totalServicios = 0;
          _salonesVisitados = 0;
        });
      }
    } catch (e) {
      print('❌ Error cargando estadísticas: $e');
      if (!mounted) return;
      setState(() {
        _citasPendientes = 0;
        _totalServicios = 0;
        _salonesVisitados = 0;
      });
    }
  }

  Future<void> _verificarCitasFinalizadas() async {
    try {
      if (_uidUsuario == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

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

      final citasCompletadas =
          citasData.where((cita) => cita['estado'] == 'completada').toList();

      if (citasCompletadas.isEmpty) {
        print('ℹ️ No hay citas completadas');
        return;
      }

      print('📋 Encontradas ${citasCompletadas.length} citas completadas');

      for (var cita in citasCompletadas.take(1)) {
        final citaId = cita['id'];

        if (citaId == null) continue;

        final resenasUrl =
            Uri.parse('$apiBaseUrl/api/resenas?cita_id=$citaId');
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

            break;
          }
        } else {
          print(
              '⚠️ Error verificando reseñas: ${resenasResponse.statusCode}');
        }
      }
    } catch (e) {
      print('❌ Error verificando citas finalizadas: $e');
    }
  }

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
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.celebration,
                color: AppTheme.primaryOrange,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Gracias por tu visita!',
                style: AppTheme.heading3,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esperamos que hayas disfrutado tu experiencia.',
              style: AppTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardDecoration(borderRadius: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store,
                          size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          salonName,
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.design_services,
                          size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cita['servicio_nombre'] ?? 'Servicio',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Te gustaría compartir tu opinión sobre el servicio recibido?',
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu reseña nos ayuda a mejorar y ayuda a otros clientes a tomar decisiones.',
              style: AppTheme.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Ahora no',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
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
                _verificarCitasFinalizadas();
              });
            },
            icon: const Icon(Icons.star, color: Colors.white),
            label: const Text(
              'Dejar reseña',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: AppTheme.primaryButtonStyle(),
          ),
        ],
      ),
    );
  }

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
        final nombreNormalizado = _normalizarTexto(salon['nombre'] ?? '');
        if (nombreNormalizado.contains(textoNormalizado)) {
          return true;
        }

        final servicios = salon['servicios'] as List<dynamic>?;
        if (servicios != null) {
          return servicios.any((servicio) {
            final nombreServicio =
                _normalizarTexto(servicio['nombre'] ?? '');
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

  // ---------- UI HELPERS ----------

  Widget _buildSalonesDestacadosSection() {
    if (_isLoading) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange),
        ),
      );
    } else if (_salonesFiltrados.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: AppTheme.cardDecoration(borderRadius: 20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store_outlined,
                  size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
              if (_categoriaSeleccionada != null || _isBuscando) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    _searchController.clear();
                    _filtrarPorCategoria('Todos');
                  },
                  style: AppTheme.primaryButtonStyle(),
                  child: const Text('Ver todos los salones'),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      return _buildSalonHorizontalList(_salonesFiltrados);
    }
  }

  Widget _buildSalonHorizontalList(List<Map<String, dynamic>> salones) {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: salones.length,
        itemBuilder: (context, i) {
          final salon = salones[i];
          final distancia = salon['distancia'] as double;

          final fotoUrl = salon['foto_url'] as String?;

          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () {
                final comercioId = salon['id'];
                if (comercioId == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SalonProfilePage(comercioId: comercioId),
                  ),
                );
              },
              child: Container(
                width: 220,
                decoration:
                    AppTheme.elevatedCardDecoration(borderRadius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                      child: SizedBox(
                        width: 220,
                        height: 140,
                        child: (fotoUrl != null && fotoUrl.isNotEmpty)
                            ? Image.network(
                                fotoUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        Container(
                                  decoration: const BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                  ),
                                  child: const Icon(
                                    Icons.store,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Container(
                                decoration: const BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            salon['nombre'] ?? '',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 14, color: Color(0xFFFFB800)),
                              const SizedBox(width: 4),
                              Text(
                                "${salon['calificacion'] ?? 4.5}",
                                style: AppTheme.caption,
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.place,
                                  size: 14, color: AppTheme.textSecondary),
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
    );
  }

  Widget _buildBannerDescuentos() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PromocionesPage()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2196F3),
                Color(0xFF00BCD4),
                Color(0xFF4CAF50),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_offer,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡Descuentos exclusivos!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aprovecha las promociones del día',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeneficiosBeauteek() {
    final beneficios = [
      {
        'icon': Icons.verified_user,
        'titulo': 'Salones verificados',
        'descripcion': 'Solo trabajamos con profesionales certificados',
        'color': const Color(0xFF4CAF50),
      },
      {
        'icon': Icons.calendar_today,
        'titulo': 'Reserva fácil',
        'descripcion': 'Agenda tu cita en segundos desde tu celular',
        'color': const Color(0xFF2196F3),
      },
      {
        'icon': Icons.star,
        'titulo': 'Reseñas reales',
        'descripcion': 'Lee opiniones de clientes verificados',
        'color': const Color(0xFFFF9800),
      },
      {
        'icon': Icons.location_on,
        'titulo': 'Encuentra cerca',
        'descripcion': 'Los mejores salones en tu zona',
        'color': const Color(0xFFE91E63),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Por qué elegir Beauteek?',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: beneficios.length,
            itemBuilder: (context, index) {
              final beneficio = beneficios[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (beneficio['color'] as Color).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (beneficio['color'] as Color).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        beneficio['icon'] as IconData,
                        color: beneficio['color'] as Color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      beneficio['titulo'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      beneficio['descripcion'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticasSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Citas pendientes
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFEA963A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B9D).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.event_available,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_citasPendientes',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _citasPendientes == 1
                        ? 'Cita\npendiente'
                        : 'Citas\npendientes',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Total servicios
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.spa,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_totalServicios',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _totalServicios == 1
                        ? 'Servicio\nreservado'
                        : 'Servicios\nreservados',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Salones visitados
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF11998E).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_salonesVisitados',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _salonesVisitados == 1
                        ? 'Salón\nvisitado'
                        : 'Salones\nvisitados',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.3,
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

  Widget _buildVisitasRecientesSection() {
    final recientes = _salonesDestacados.length > 5
        ? _salonesDestacados.take(5).toList()
        : _salonesDestacados;
    return _buildSalonHorizontalList(recientes);
  }

  Widget _buildNuevosSalonesSection() {
    final nuevos = _salonesDestacados.length > 3
        ? _salonesDestacados.reversed.take(3).toList()
        : _salonesDestacados;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: nuevos.map((salon) {
          final distancia = salon['distancia'] as double;
          final fotoUrl = salon['foto_url'] as String?;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AppTheme.cardDecoration(borderRadius: 16),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: (fotoUrl != null && fotoUrl.isNotEmpty)
                        ? Image.network(
                            fotoUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                            ),
                            child: const Icon(
                              Icons.store,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salon['nombre'] ?? '',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'A ${distancia.toStringAsFixed(1)} km de ti',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Nuevo',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ----------------- BUILD -----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // futuro botón IA
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
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileMenuPage(uid: uid),
                        ),
                      );
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                      ),
                      child:
                          _fotoUsuario != null && _fotoUsuario!.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    _fotoUsuario!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 28,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
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
                          'Hola, $_nombreUsuario',
                          style: AppTheme.heading3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Encuentra tu próximo look',
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NotificacionesPage(),
                            ),
                          );
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

            // CATEGORÍAS
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categorias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final categoria = categorias[index]['nombre'] as String;
                  final seleccionada = _categoriaSeleccionada == categoria;

                  final baseColors = <Color>[
                    AppTheme.primaryOrange,
                    const Color(0xFF2563EB),
                    const Color(0xFF10B981),
                    const Color(0xFF64748B),
                  ];
                  final baseColor = baseColors[index % baseColors.length];

                  return GestureDetector(
                    onTap: () => _filtrarPorCategoria(categoria),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: seleccionada
                            ? baseColor
                            : AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: seleccionada
                              ? baseColor
                              : AppTheme.dividerColor,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          categoria,
                          style: AppTheme.bodyMedium.copyWith(
                            fontSize: 13,
                            color: seleccionada
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontWeight: seleccionada
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // BARRA DE BÚSQUEDA
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
                        onSubmitted: (texto) {
                          if (texto.trim().isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompararServiciosPage(
                                  servicioNombre: texto.trim(),
                                ),
                              ),
                            );
                          }
                        },
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText:
                              'Buscar salones, uñas, peinados...',
                          hintStyle: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_textoBusqueda.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.compare_arrows,
                          color: AppTheme.primaryOrange,
                          size: 22,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompararServiciosPage(
                                servicioNombre: _textoBusqueda,
                              ),
                            ),
                          );
                        },
                      ),
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
                  ],
                ),
              ),
            ),

            // CONTENIDO PRINCIPAL
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // BANNER DE DESCUENTOS
                    _buildBannerDescuentos(),

                    const SizedBox(height: 16),

                    // PROMOS DEL DÍA
                    if (_promocionesActivas.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          'Promos del día',
                          style: AppTheme.heading2,
                        ),
                      ),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _promocionesActivas.length,
                          itemBuilder: (context, index) {
                            final promo = _promocionesActivas[index];
                            final descuento = promo['valor'] ?? 0;
                            final fotoUrl = promo['foto_url'] as String?;
                            final precioOriginal =
                                promo['precio_original'];
                            final precioDescuento =
                                promo['precio_con_descuento'];

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PromocionesPage(),
                                  ),
                                );
                              },
                              child: Container(
                                width: 280,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFF6B9D)
                                          .withOpacity(0.8),
                                      const Color(0xFFEA963A)
                                          .withOpacity(0.8),
                                    ],
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    if (fotoUrl != null &&
                                        fotoUrl.isNotEmpty)
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        child: Image.network(
                                          fotoUrl,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, __, ___) =>
                                                  const SizedBox(),
                                        ),
                                      ),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black
                                                .withOpacity(0.7),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets
                                                    .symmetric(
                                                horizontal: 12,
                                                vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      20),
                                            ),
                                            child: Text(
                                              '-$descuento% OFF',
                                              style: const TextStyle(
                                                color:
                                                    Color(0xFFEA963A),
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            promo['servicio_nombre'] ??
                                                'Servicio',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              if (precioOriginal !=
                                                  null)
                                                Text(
                                                  '\$$precioOriginal',
                                                  style:
                                                      const TextStyle(
                                                    color:
                                                        Colors.white70,
                                                    fontSize: 14,
                                                    decoration:
                                                        TextDecoration
                                                            .lineThrough,
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              if (precioDescuento !=
                                                  null)
                                                Text(
                                                  '\$$precioDescuento',
                                                  style:
                                                      const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.bold,
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
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // SALONES DESTACADOS
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
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
                          if (_categoriaSeleccionada != null ||
                              _isBuscando)
                            GestureDetector(
                              onTap: () =>
                                  _filtrarPorCategoria('Todos'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryOrange
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.clear,
                                      size: 16,
                                      color: AppTheme.primaryOrange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Limpiar',
                                      style:
                                          AppTheme.caption.copyWith(
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
                    _buildSalonesDestacadosSection(),

                    const SizedBox(height: 24),

                    // TU ACTIVIDAD
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                      child: Text(
                        'Tu actividad',
                        style: AppTheme.heading2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildEstadisticasSection(),

                    const SizedBox(height: 24),

                    // BENEFICIOS DE BEAUTEEK
                    _buildBeneficiosBeauteek(),

                    const SizedBox(height: 24),

                    if (_salonesDestacados.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        child: Text(
                          'Basado en tus visitas recientes',
                          style: AppTheme.heading2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildVisitasRecientesSection(),

                      const SizedBox(height: 24),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        child: Text(
                          'Nuevos salones en tu zona',
                          style: AppTheme.heading2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildNuevosSalonesSection(),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          border: Border(
            top: BorderSide(color: AppTheme.dividerColor),
          ),
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      builder: (_) => const PromocionesPage(),
                    ),
                  );
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
    final color =
        selected ? AppTheme.primaryOrange : AppTheme.textSecondary;
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