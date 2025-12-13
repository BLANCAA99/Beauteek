import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_constants.dart';
import 'salon_profile_page.dart';
import 'theme/app_theme.dart';
import 'comparar_servicios_page.dart';

class SearchPage extends StatefulWidget {
  final String mode;
  final String? initialCategory;
  final List<Map<String, dynamic>>? salonesFiltrados;
  final String? userCountry;
  final String? userId;
  final Function(LatLng position, String address)? onLocationSelected;

  const SearchPage({
    Key? key,
    required this.mode,
    this.initialCategory,
    this.salonesFiltrados,
    this.userCountry,
    this.userId,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Map<String, dynamic>> _resultados = [];
  bool _isLoading = true;
  double? _userLat;
  double? _userLng;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _showMap = true; // Mostrar mapa por defecto

  // UI: pestañas "Salones / Servicios"
  int _indicePestana = 0;
  
  // Búsqueda
  final TextEditingController _busquedaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print(
        '🔍 SearchPage initialized - mode: ${widget.mode}, userId: ${widget.userId}');

    if (widget.mode == 'search') {
      _cargarSalonesPorPais();
    } else if (widget.mode == 'category' && widget.salonesFiltrados != null) {
      _resultados = widget.salonesFiltrados!;
      _cargarSalonesPorPais();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  // ✅ NUEVO: Cargar salones usando la colección ubicaciones
  Future<void> _cargarSalonesPorPais() async {
    try {
      if (widget.userId == null) {
        print('⚠️ userId es null');
        setState(() => _isLoading = false);
        return;
      }

      // NUEVO: Obtener ubicación principal del cliente desde colección ubicaciones
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final idToken = await user.getIdToken();
      final ubicacionUrl = Uri.parse('$apiBaseUrl/api/ubicaciones/principal/${widget.userId}?tipo=cliente');
      final ubicacionResponse = await http.get(
        ubicacionUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (ubicacionResponse.statusCode != 200) {
        print('⚠️ Cliente sin ubicación principal');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Configura tu ubicación primero'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final ubicacionData = json.decode(ubicacionResponse.body);
      final pais = ubicacionData['pais'];
      final userLat = (ubicacionData['lat'] as num).toDouble();
      final userLng = (ubicacionData['lng'] as num).toDouble();

      setState(() {
        _userLat = userLat;
        _userLng = userLng;
      });

      print('🌍 País del cliente: $pais');
      print('📍 Ubicación del cliente: ($userLat, $userLng)');

      // NUEVO: Buscar salones por país desde colección ubicaciones
      final salonesUrl = Uri.parse('$apiBaseUrl/api/ubicaciones/salones/pais/$pais');
      final salonesResponse = await http.get(
        salonesUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 30));
      
      final List<dynamic> salones = salonesResponse.statusCode == 200 
          ? json.decode(salonesResponse.body) 
          : [];

      print('📊 Salones encontrados en $pais: ${salones.length}');

      // Calcular distancia para cada salón
      final salonesConDistancia = salones.map<Map<String, dynamic>>((salon) {
        final salonMap = salon as Map<String, dynamic>;
        final ubicacionSalon = salonMap['ubicacion'] as Map<String, dynamic>?;
        
        if (ubicacionSalon != null) {
          final salonLat = (ubicacionSalon['lat'] as num?)?.toDouble();
          final salonLng = (ubicacionSalon['lng'] as num?)?.toDouble();
          
          if (salonLat != null && salonLng != null) {
            final distancia = _calcularDistancia(
              userLat, userLng, salonLat, salonLng,
            );
            salonMap['distancia'] = distancia;
            salonMap['distancia_km'] = distancia;
          } else {
            salonMap['distancia'] = 999999.0;
            salonMap['distancia_km'] = 999999.0;
          }
        }
        
        return salonMap;
      }).toList();

      // Ordenar por distancia (los más cercanos primero)
      salonesConDistancia.sort((a, b) {
        final distA = a['distancia_km'] as double? ?? double.infinity;
        final distB = b['distancia_km'] as double? ?? double.infinity;
        return distA.compareTo(distB);
      });

      setState(() {
        _resultados = salonesConDistancia;
        _isLoading = false;
      });

      print('✅ ${_resultados.length} salones cargados en $pais (ordenados por distancia)');
      
      // Actualizar marcadores inmediatamente al cargar los salones
      _actualizarMarcadores();
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  // Calcular distancia usando fórmula de Haversine
  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Radio de la Tierra en km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  String _formatearDistancia(double? distancia) {
    if (distancia == null || distancia == double.infinity) {
      return '';
    }
    if (distancia < 1) {
      return '${(distancia * 1000).toStringAsFixed(0)} m';
    }
    return '${distancia.toStringAsFixed(1)} km';
  }

  // Función para abrir Google Maps con direcciones
  Future<void> _abrirGoogleMaps(double lat, double lng, String nombreSalon) async {
    // URL para Google Maps con direcciones desde la ubicación actual
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        print('📍 Abriendo Google Maps para: $nombreSalon');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir Google Maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error abriendo Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al abrir el mapa'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleMapa() {
    setState(() {
      _showMap = !_showMap;
      if (_showMap) {
        _actualizarMarcadores();
      }
    });
  }

  void _mostrarOpcionesSalon(Map<String, dynamic> salon, double lat, double lng) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                salon['nombre'] ?? 'Salón',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.store, color: AppTheme.primaryOrange),
                title: const Text(
                  'Ver perfil del salón',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SalonProfilePage(
                        comercioId: salon['id'],
                      ),
                    ),
                  );
                },
              ),
              const Divider(color: AppTheme.dividerColor),
              ListTile(
                leading: const Icon(Icons.directions, color: AppTheme.primaryOrange),
                title: const Text(
                  '¿Cómo llegar?',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                subtitle: const Text(
                  'Abrir en Google Maps',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _abrirGoogleMaps(lat, lng, salon['nombre'] ?? 'Salón');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _actualizarMarcadores() {
    _markers.clear();
    _circles.clear();

    if (_userLat != null && _userLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('usuario'),
          position: LatLng(_userLat!, _userLng!),
          infoWindow: const InfoWindow(title: 'Mi ubicación'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );

      _circles.add(
        Circle(
          circleId: const CircleId('radio_busqueda'),
          center: LatLng(_userLat!, _userLng!),
          radius: 10000,
          fillColor: Colors.orange.withOpacity(0.1),
          strokeColor: Colors.orange.withOpacity(0.5),
          strokeWidth: 2,
        ),
      );
    }

    for (int i = 0; i < _resultados.length; i++) {
      final salon = _resultados[i];
      final ubicacion = salon['ubicacion'] as Map<String, dynamic>?;

      if (ubicacion != null) {
        final lat = (ubicacion['lat'] ?? ubicacion['_latitude'] ?? ubicacion['latitude'])?.toDouble();
        final lng = (ubicacion['lng'] ?? ubicacion['_longitude'] ?? ubicacion['longitude'])?.toDouble();

        if (lat != null && lng != null) {
          _markers.add(
            Marker(
              markerId: MarkerId('salon_$i'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: salon['nombre'],
                snippet: 'Toca para ver perfil • ${(salon['distancia'] as double).toStringAsFixed(1)} km',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SalonProfilePage(
                        comercioId: salon['id'],
                      ),
                    ),
                  );
                },
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              onTap: () {
                // Mostrar diálogo con opciones
                _mostrarOpcionesSalon(salon, lat, lng);
              },
            ),
          );
        }
      }
    }

    setState(() {});
  }

  // ========= UI NUEVA PARA LA LISTA =========

  Widget _construirBuscadorYFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          // Barra de búsqueda
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFFB0B0B0), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _busquedaController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    cursorColor: AppTheme.primaryOrange,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Buscar salones, servicios...',
                      hintStyle: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 16,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CompararServiciosPage(
                              servicioNombre: value.trim(),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Filtros (solo Ordenar, sin distancia ni precio)
          Align(
            alignment: Alignment.centerLeft,
            child: _chipFiltro(
              icono: Icons.tune_rounded,
              texto: 'Ordenar',
              onTap: () {
                // Aquí luego puedes abrir bottom sheet de ordenamiento
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipFiltro({
    required IconData icono,
    required String texto,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              texto,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // 👉 Tabs centradas + línea gris como en el diseño
  Widget _construirPestanas() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _pestana('Salones', 0),
            _pestana('Servicios', 1),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          color: AppTheme.dividerColor.withOpacity(0.6),
        ),
      ],
    );
  }

  Widget _pestana(String titulo, int indice) {
    final bool seleccionado = _indicePestana == indice;

    return GestureDetector(
      onTap: () {
        setState(() {
          _indicePestana = indice;
        });
      },
      child: Column(
        children: [
          Text(
            titulo,
            style: TextStyle(
              color:
                  seleccionado ? AppTheme.primaryOrange : AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: 80,
            decoration: BoxDecoration(
              color: seleccionado ? AppTheme.primaryOrange : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  String _descripcionSalon(Map<String, dynamic> salon, double? distancia) {
    final partes = <String>[];

    final categoria =
        salon['categoria'] ?? salon['tipo'] ?? salon['categoriaPrincipal'];

    if (categoria != null && categoria.toString().isNotEmpty) {
      partes.add(categoria.toString());
    }

    if (distancia != null && distancia != double.infinity) {
      partes.add(_formatearDistancia(distancia));
    }

    final rangoPrecios = salon['rango_precios'] ?? salon['price_level'];
    if (rangoPrecios != null && rangoPrecios.toString().isNotEmpty) {
      partes.add(rangoPrecios.toString());
    }

    return partes.join(' • ');
  }

  Widget _construirListaSalones() {
    if (_indicePestana == 1) {
      // Pestaña "Servicios" (por ahora placeholder)
      return const Center(
        child: Text(
          'Próximamente servicios',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _resultados.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final salon = _resultados[index];
        final distancia = salon['distancia'] as double?;

        final calificacion = (salon['calificacion'] ?? 4.8).toDouble();
        final descripcion = _descripcionSalon(salon, distancia);

        return GestureDetector(
          onTap: () {
            print('🔍 Navegando a salon: ${salon['nombre']}');
            print('   comercioId: ${salon['id']}');

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SalonProfilePage(
                  comercioId: salon['id'],
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Texto
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rating
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFEA963A),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              calificacion.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Nombre
                        Text(
                          salon['nombre'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Descripción (categoría • distancia • precio)
                        if (descripcion.isNotEmpty)
                          Text(
                            descripcion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFB0B0B0),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Imagen
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: salon['foto_url'] != null
                        ? Image.network(
                            salon['foto_url']!,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _placeholderImagen();
                            },
                          )
                        : _placeholderImagen(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholderImagen() {
    return Container(
      width: 110,
      height: 110,
      color: AppTheme.primaryOrange.withOpacity(0.2),
      child: const Icon(
        Icons.store,
        color: AppTheme.primaryOrange,
        size: 36,
      ),
    );
  }

  // 👉 Botón tipo pastilla centrado con sombra (como la referencia)
  Widget _botonVerEnMapa() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              width: 260,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _toggleMapa,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.map),
                label: const Text(
                  'Ver en mapa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Modo selector de ubicación
    if (widget.mode == 'select') {
      return _MapLocationSelector(
        onLocationSelected: widget.onLocationSelected,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Buscar',
          style: AppTheme.heading3,
        ),
        // sin icono de mapa aquí, el toggle se hace con los botones inferiores
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : _showMap && _userLat != null
              // ===== VISTA MAPA =====
              ? Column(
                  children: [
                    Expanded(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(_userLat!, _userLng!),
                          zoom: 14,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        markers: _markers,
                        circles: _circles,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                      ),
                    ),
                    // Botón que te lleva a la lista
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.cardBackground,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _toggleMapa,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.list),
                          label: Text(
                            '${_resultados.length} salones',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              // ===== VISTA LISTA =====
              : _resultados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store_outlined,
                            color: AppTheme.textSecondary,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay salones cercanos',
                            style: AppTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _construirBuscadorYFiltros(),
                        _construirPestanas(),
                        const SizedBox(height: 12),
                        Expanded(child: _construirListaSalones()),
                        _botonVerEnMapa(),
                      ],
                    ),
    );
  }
}

// ================== _MapLocationSelector (SIN CAMBIOS DE LÓGICA) ==================

class _MapLocationSelector extends StatefulWidget {
  final Function(LatLng position, String address)? onLocationSelected;

  const _MapLocationSelector({this.onLocationSelected});

  @override
  State<_MapLocationSelector> createState() => _MapLocationSelectorState();
}

class _MapLocationSelectorState extends State<_MapLocationSelector> {
  GoogleMapController? _mapController;
  LatLng _selectedPosition = const LatLng(14.0723, -87.1921);
  bool _isLoadingLocation = false;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // Crear marcador inicial inmediatamente
    _markers = {
      Marker(
        markerId: const MarkerId('selected_location'),
        position: _selectedPosition,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onDragEnd: _onMarkerDragEnd,
      ),
    };
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    await _requestLocationPermissions();
    await _getCurrentLocation();
  }

  Future<void> _requestLocationPermissions() async {
    try {
      final permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnackBar(
              'Abre Configuración > Aplicaciones > Beauteek > Permisos > Ubicación');
        }
      }
    } catch (e) {
      print('❌ Error solicitando permisos: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('⚠️ Permiso de ubicación denegado');
        if (mounted) {
          _showSnackBar(
              'Permiso de ubicación denegado. Usando ubicación por defecto.');
        }
        if (mounted) {
          setState(() => _isLoadingLocation = false);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          print(
              '⏱️ Timeout obteniendo ubicación, usando coordenadas por defecto');
          return Position(
            latitude: 14.0723,
            longitude: -87.1921,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        },
      );

      final newPosition = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _selectedPosition = newPosition;
          _updateMarker(newPosition);
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 15),
        );

        print('✅ Ubicación actual obtenida: $newPosition');
      }
    } catch (e) {
      print('❌ Error obteniendo ubicación: $e');
      if (mounted) {
        _showSnackBar('No se pudo obtener tu ubicación actual');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _updateMarker(LatLng position) {
    if (mounted) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('selected_location'),
            position: position,
            draggable: true,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            onDragEnd: _onMarkerDragEnd,
          ),
        };
      });
      print('📍 Marcador actualizado en: $position');
    }
  }

  void _onMarkerDragEnd(LatLng newPosition) {
    if (mounted) {
      setState(() {
        _selectedPosition = newPosition;
      });
    }
  }

  void _onMapTap(LatLng position) {
    if (mounted) {
      setState(() {
        _selectedPosition = position;
        _updateMarker(position);
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmLocation() {
    if (widget.onLocationSelected != null) {
      final address = 'Lat: ${_selectedPosition.latitude.toStringAsFixed(5)}, '
          'Lng: ${_selectedPosition.longitude.toStringAsFixed(5)}';
      widget.onLocationSelected!(_selectedPosition, address);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              print('📍 Mapa creado. Marcadores actuales: ${_markers.length}');
            },
            onTap: _onMapTap,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color(0xFF111418)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seleccionar ubicación',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111418),
                            ),
                          ),
                          Text(
                            'Toca el mapa o arrastra el marcador',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF637588),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton(
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              backgroundColor: Colors.white,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFEA963A),
                      ),
                    )
                  : const Icon(
                      Icons.my_location,
                      color: Color(0xFFEA963A),
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFFEA963A),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ubicación seleccionada',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF637588),
                                  ),
                                ),
                                Text(
                                  'Lat: ${_selectedPosition.latitude.toStringAsFixed(5)}, '
                                  'Lng: ${_selectedPosition.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111418),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA963A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirmar ubicación',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}