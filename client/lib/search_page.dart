import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' show cos, sqrt, asin;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_constants.dart';
import 'salon_profile_page.dart';
import 'theme/app_theme.dart';

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
  bool _showMap = true;

  @override
  void initState() {
    super.initState();
    print(
        '🔍 SearchPage initialized - mode: ${widget.mode}, userId: ${widget.userId}');

    if (widget.mode == 'search') {
      // ✅ Cargar salones cercanos automáticamente
      _cargarSalonesCercanos();
    } else if (widget.mode == 'category' && widget.salonesFiltrados != null) {
      _resultados = widget.salonesFiltrados!;
      _cargarSalonesCercanos();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ✅ IGUAL QUE EN INICIO.DART
  Future<void> _cargarSalonesCercanos() async {
    try {
      if (widget.userId == null) {
        print('⚠️ userId es null');
        setState(() => _isLoading = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No hay usuario autenticado');
        setState(() => _isLoading = false);
        return;
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        print('⚠️ No se pudo obtener el token');
        setState(() => _isLoading = false);
        return;
      }

      // Primero obtener ubicación del usuario
      await _obtenerUbicacionUsuario(idToken);

      if (_userLat == null || _userLng == null) {
        print('⚠️ No se pudo obtener ubicación del usuario');
        setState(() => _isLoading = false);
        return;
      }

      print(
          '🔍 Buscando comercios cerca de ($_userLat, $_userLng) - radio: 10 km');

      // ✅ Usar apiBaseUrl de api_constants.dart
      final url = Uri.parse(
          '$apiBaseUrl/comercios/cerca?lat=$_userLat&lng=$_userLng&radio=10');

      print('📍 URL completa: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> saloneData = json.decode(response.body);

        print('📊 Salones encontrados: ${saloneData.length}');
        for (var salon in saloneData) {
          print('  - ${salon['nombre']}: ${salon['distancia']} km');
        }

        setState(() {
          _resultados = List<Map<String, dynamic>>.from(
              saloneData.map((s) => s as Map<String, dynamic>));
          _isLoading = false;
        });

        print('✅ ${_resultados.length} salones cargados');
        _actualizarMarcadores();
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        print('📝 Response: ${response.body}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ IGUAL QUE EN INICIO.DART
  Future<void> _obtenerUbicacionUsuario(String idToken) async {
    try {
      final uid = widget.userId;
      if (uid == null) return;

      // ✅ Usar EXACTAMENTE el mismo endpoint que inicio.dart
      final url = Uri.parse('$apiBaseUrl/api/users/uid/$uid');
      print('🔍 Obteniendo usuario: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final userData = json.decode(response.body) as Map<String, dynamic>;

        print('👤 Datos del usuario obtenidos');
        print('📍 Ubicación RAW: ${userData['ubicacion']}');

        final ubicacion = userData['ubicacion'];
        double? lat, lng;

        // ✅ Manejo de múltiples formatos (igual que inicio.dart)
        if (ubicacion is Map) {
          lat = (ubicacion['_latitude'] ?? ubicacion['latitude'])?.toDouble();
          lng = (ubicacion['_longitude'] ?? ubicacion['longitude'])?.toDouble();
          print('📍 Formato: Map');
        } else if (ubicacion is List && ubicacion.length >= 2) {
          lat = (ubicacion[0] as num?)?.toDouble();
          lng = (ubicacion[1] as num?)?.toDouble();
          print('📍 Formato: List/Array');
        }

        print('📍 Lat parseada: $lat');
        print('📍 Lng parseada: $lng');

        if (lat != null && lng != null) {
          setState(() {
            _userLat = lat;
            _userLng = lng;
          });
          print('✅ Ubicación del usuario: $_userLat, $_userLng');
        }
      } else {
        print('❌ Error obteniendo usuario: ${response.statusCode}');
        print('📝 Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error obteniendo ubicación: $e');
    }
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

      // ✅ CAMBIO: Leer ubicacion del comercio (no geo de sucursal)
      final ubicacion = salon['ubicacion'] as Map<String, dynamic>?;

      if (ubicacion != null) {
        final lat = (ubicacion['lat'] ??
                ubicacion['_latitude'] ??
                ubicacion['latitude'])
            ?.toDouble();
        final lng = (ubicacion['lng'] ??
                ubicacion['_longitude'] ??
                ubicacion['longitude'])
            ?.toDouble();

        if (lat != null && lng != null) {
          _markers.add(
            Marker(
              markerId: MarkerId('salon_$i'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: salon['nombre'],
                snippet:
                    '${(salon['distancia'] as double).toStringAsFixed(1)} km',
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
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange),
            ),
          );
        }
      }
    }

    setState(() {});
    print('📍 ${_markers.length} marcadores actualizados');
  }

  String _formatearDistancia(double? distancia) {
    if (distancia == null || distancia == double.infinity) {
      return '';
    }
    if (distancia < 1) {
      return '${(distancia * 1000).toStringAsFixed(0)}m';
    }
    return '${distancia.toStringAsFixed(1)}km';
  }

  void _toggleMapa() {
    setState(() {
      _showMap = !_showMap;
      if (_showMap) {
        _actualizarMarcadores();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CAMBIO: Mostrar mapa selector cuando mode == 'select'
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
          'Salones cercanos',
          style: AppTheme.heading3,
        ),
        actions: [
          if (_resultados.isNotEmpty && _userLat != null)
            Tooltip(
              message: _showMap ? 'Ver lista' : 'Ver mapa',
              child: IconButton(
                icon: Icon(
                  _showMap ? Icons.list : Icons.map,
                  color: AppTheme.primaryOrange,
                  size: 28,
                ),
                onPressed: _toggleMapa,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : _showMap && _userLat != null
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.cardBackground,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _toggleMapa,
                          style: AppTheme.primaryButtonStyle(),
                          icon: const Icon(Icons.list),
                          label: Text(
                            '${_resultados.length} Salones',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
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
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _resultados.length,
                      itemBuilder: (context, index) {
                        final salon = _resultados[index];
                        final distancia = salon['distancia'] as double?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: AppTheme.elevatedCardDecoration(),
                          child: InkWell(
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
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: salon['foto_url'] != null
                                        ? Image.network(
                                            salon['foto_url']!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                width: 80,
                                                height: 80,
                                                color: AppTheme.primaryOrange
                                                    .withOpacity(0.2),
                                                child: const Icon(
                                                  Icons.store,
                                                  color: AppTheme.primaryOrange,
                                                  size: 32,
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            width: 80,
                                            height: 80,
                                            color: AppTheme.primaryOrange
                                                .withOpacity(0.2),
                                            child: const Icon(
                                              Icons.store,
                                              color: AppTheme.primaryOrange,
                                              size: 32,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                salon['nombre']!,
                                                style:
                                                    AppTheme.bodyLarge.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (distancia != null &&
                                                distancia !=
                                                    double.infinity) ...[
                                              Text(
                                                _formatearDistancia(distancia),
                                                style: AppTheme.caption,
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.location_on,
                                                color: AppTheme.primaryOrange,
                                                size: 16,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Color(0xFFEA963A),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${salon['calificacion'] ?? 4.5} • ${salon['reviews'] ?? 0} reviews",
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF637588),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF637588),
                                    size: 24,
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
}

// Widget para selector de ubicación
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
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
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
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('selected_location'),
        position: position,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onDragEnd: _onMarkerDragEnd,
      ),
    );
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
              if (mounted) {
                setState(() {
                  _updateMarker(_selectedPosition);
                });
              }
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
