import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchPage extends StatefulWidget {
  // Modo de uso: 'search' para buscar salones, 'select' para seleccionar dirección
  final String mode;
  final Function(LatLng, String)? onLocationSelected; // Callback para modo select
  
  const SearchPage({
    Key? key,
    this.mode = 'search',
    this.onLocationSelected,
  }) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(15.5, -88.0);
  LatLng? _selectedPosition; // Para modo select
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _salonesCercanos = [];
  bool _isLoading = true;
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  double _radioKm = 10.0;
  String _selectedAddress = '';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Obtener ubicación actual del usuario
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Los servicios de ubicación están desactivados');
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Permiso de ubicación denegado');
          setState(() => _isLoading = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 14),
      );

      // Solo cargar salones si estamos en modo 'search'
      if (widget.mode == 'search') {
        await _loadSalonesCercanos();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      _showError('Error al obtener tu ubicación');
      setState(() => _isLoading = false);
    }
  }

  // Cargar salones cercanos desde Firestore (buscar en sucursales, no comercios)
  Future<void> _loadSalonesCercanos() async {
    try {
      // Obtener todas las sucursales activas
      final sucursalesSnapshot = await FirebaseFirestore.instance
          .collection('sucursales')
          .where('estado', isEqualTo: 'activo')
          .get();

      List<Map<String, dynamic>> salones = [];
      Set<Marker> markers = {};

      for (var doc in sucursalesSnapshot.docs) {
        final data = doc.data();
        if (data['geo'] != null) {
          final GeoPoint geoPoint = data['geo'];
          final LatLng sucursalPos = LatLng(geoPoint.latitude, geoPoint.longitude);

          // Calcular distancia
          final distanciaMetros = Geolocator.distanceBetween(
            _currentPosition.latitude,
            _currentPosition.longitude,
            sucursalPos.latitude,
            sucursalPos.longitude,
          );
          final distanciaKm = distanciaMetros / 1000;

          // Filtrar por radio
          if (distanciaKm <= _radioKm) {
            // Obtener info del comercio
            final comercioId = data['comercio_id'];
            final comercioDoc = await FirebaseFirestore.instance
                .collection('comercios')
                .doc(comercioId)
                .get();
            
            final comercioData = comercioDoc.data();
            final nombreComercio = comercioData?['nombre'] ?? 'Sin nombre';
            final esPrincipal = data['es_principal'] ?? false;

            salones.add({
              'id': doc.id,
              'comercio_id': comercioId,
              'nombre': esPrincipal 
                  ? nombreComercio 
                  : data['nombre'] ?? '$nombreComercio - Sucursal',
              'direccion': data['direccion'] ?? 'Sin dirección',
              'telefono': data['telefono'] ?? '',
              'distancia': distanciaKm,
              'position': sucursalPos,
              'es_principal': esPrincipal,
              'rating': 4.5, // TODO: Calcular rating real
              'reviews': 0, // TODO: Contar reseñas reales
            });

            // Crear marcador en el mapa
            markers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: sucursalPos,
                icon: esPrincipal
                    ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
                    : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: esPrincipal ? '$nombreComercio (Principal)' : data['nombre'],
                  snippet: '${distanciaKm.toStringAsFixed(1)} km',
                ),
                onTap: () {
                  final index = salones.indexWhere((s) => s['id'] == doc.id);
                  if (index != -1) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            );
          }
        }
      }

      // Ordenar salones por distancia
      salones.sort((a, b) => a['distancia'].compareTo(b['distancia']));

      setState(() {
        _salonesCercanos = salones;
        _markers = markers;
        _isLoading = false;
      });

      print('✅ ${salones.length} sucursales encontradas dentro de $_radioKm km');
    } catch (e) {
      print('Error cargando salones: $e');
      setState(() => _isLoading = false);
      _showError('Error al cargar salones cercanos');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  void _showFiltros() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtros',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text('Radio: ${_radioKm.toStringAsFixed(0)} km'),
              Slider(
                value: _radioKm,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${_radioKm.toStringAsFixed(0)} km',
                onChanged: (val) => setModalState(() => _radioKm = val),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA963A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    _loadSalonesCercanos();
                  },
                  child: const Text(
                    'Aplicar filtros',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Para modo 'select': confirmar ubicación seleccionada
  void _confirmLocation() {
    if (_selectedPosition != null && widget.onLocationSelected != null) {
      widget.onLocationSelected!(_selectedPosition!, _selectedAddress);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 14,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
            onTap: widget.mode == 'select'
                ? (position) {
                    setState(() {
                      _selectedPosition = position;
                      _markers = {
                        Marker(
                          markerId: const MarkerId('selected'),
                          position: position,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueOrange,
                          ),
                        ),
                      };
                      _selectedAddress = 'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}';
                    });
                  }
                : null,
          ),

          // Barra superior
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Botón volver
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                // Barra de búsqueda o título
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      widget.mode == 'search'
                          ? 'Buscar salones cercanos'
                          : 'Selecciona la ubicación',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Botón filtros (solo en modo search)
                if (widget.mode == 'search') ...[
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: _showFiltros,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Botón confirmar ubicación (solo en modo select)
          if (widget.mode == 'select' && _selectedPosition != null)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA963A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _confirmLocation,
                child: const Text(
                  'Confirmar ubicación',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Lista deslizable de salones (solo en modo search)
          if (widget.mode == 'search' && !_isLoading && _salonesCercanos.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              height: 200,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      _salonesCercanos[index]['position'],
                      15,
                    ),
                  );
                },
                itemCount: _salonesCercanos.length,
                itemBuilder: (context, index) {
                  final salon = _salonesCercanos[index];
                  return _buildSalonCard(salon, index == _currentPage);
                },
              ),
            ),

          // Indicador de carga
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFEA963A)),
              ),
            ),

          // Mensaje si no hay salones (solo en modo search)
          if (widget.mode == 'search' && !_isLoading && _salonesCercanos.isEmpty)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.search_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'No hay salones cerca',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Intenta aumentar el radio de búsqueda',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalonCard(Map<String, dynamic> salon, bool isActive) {
    return AnimatedScale(
      scale: isActive ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Imagen placeholder
            Container(
              width: 120,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: const Icon(Icons.store, size: 48, color: Colors.grey),
            ),
            // Información del salón
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      salon['nombre'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${salon['rating']} (${salon['reviews']})',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Color(0xFFEA963A)),
                        const SizedBox(width: 4),
                        Text(
                          '${salon['distancia'].toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Color(0xFFEA963A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      salon['direccion'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
