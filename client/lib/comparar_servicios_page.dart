import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'api_constants.dart';
import 'theme/app_theme.dart';
import 'calendar_page.dart';

class CompararServiciosPage extends StatefulWidget {
  final String servicioNombre;
  
  const CompararServiciosPage({
    Key? key,
    required this.servicioNombre,
  }) : super(key: key);

  @override
  State<CompararServiciosPage> createState() => _CompararServiciosPageState();
}

class _CompararServiciosPageState extends State<CompararServiciosPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _serviciosEncontrados = [];
  String _ordenPor = 'Precio';
  final List<String> _opcionesOrden = ['Precio', 'Distancia', 'Rating'];

  @override
  void initState() {
    super.initState();
    _buscarServicios();
  }

  Future<void> _buscarServicios() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      // 1. Obtener todos los comercios
      final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
      final comerciosResponse = await http.get(
        comerciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (comerciosResponse.statusCode != 200) {
        setState(() => _isLoading = false);
        return;
      }

      final List<dynamic> comercios = json.decode(comerciosResponse.body);

      // 2. Para cada comercio, obtener sus servicios
      List<Map<String, dynamic>> serviciosEncontrados = [];

      for (var comercio in comercios) {
        try {
          final serviciosUrl = Uri.parse('$apiBaseUrl/servicios/comercio/${comercio['id']}');
          final serviciosResponse = await http.get(
            serviciosUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          );

          if (serviciosResponse.statusCode == 200) {
            final List<dynamic> servicios = json.decode(serviciosResponse.body);

            // Filtrar servicios que coincidan con la búsqueda
            for (var servicio in servicios) {
              final nombreServicio = (servicio['nombre'] ?? '').toString().toLowerCase();
              final busqueda = widget.servicioNombre.toLowerCase();

              if (nombreServicio.contains(busqueda)) {
                // Calcular distancia real
                final distancia = await _calcularDistanciaReal(comercio);
                
                serviciosEncontrados.add({
                  'servicio': servicio,
                  'comercio': comercio,
                  'precio': servicio['precio'] ?? 0,
                  'duracion': servicio['duracion'] ?? 0,
                  'distancia': distancia,
                  'rating': comercio['rating'] ?? 4.0,
                  'resenas': comercio['total_resenas'] ?? 0,
                });
              }
            }
          }
        } catch (e) {
          print('Error obteniendo servicios del comercio ${comercio['id']}: $e');
        }
      }

      // 3. Ordenar por precio (menor a mayor)
      serviciosEncontrados.sort((a, b) => a['precio'].compareTo(b['precio']));

      setState(() {
        _serviciosEncontrados = serviciosEncontrados;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error buscando servicios: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<double> _calcularDistanciaReal(Map<String, dynamic> comercio) async {
    try {
      // Obtener ubicación del usuario desde Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0.0;

      final idToken = await user.getIdToken();
      final userUrl = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');
      final userResponse = await http.get(
        userUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (userResponse.statusCode != 200) return 0.0;

      final userData = json.decode(userResponse.body);
      final ubicacionUsuario = userData['ubicacion'];
      
      double? userLat, userLng;
      if (ubicacionUsuario is Map) {
        userLat = (ubicacionUsuario['_latitude'] ?? ubicacionUsuario['latitude'])?.toDouble();
        userLng = (ubicacionUsuario['_longitude'] ?? ubicacionUsuario['longitude'])?.toDouble();
      }

      if (userLat == null || userLng == null) return 0.0;

      // Obtener ubicación del comercio desde usuarios collection
      final uidUsuario = comercio['uid_usuario'];
      if (uidUsuario == null) return 0.0;
      
      final comercioUserUrl = Uri.parse('$apiBaseUrl/api/users/uid/$uidUsuario');
      final comercioUserResponse = await http.get(
        comercioUserUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (comercioUserResponse.statusCode != 200) return 0.0;

      final comercioUserData = json.decode(comercioUserResponse.body);
      final ubicacionComercio = comercioUserData['ubicacion'];
      
      double? comercioLat, comercioLng;
      if (ubicacionComercio is Map) {
        comercioLat = (ubicacionComercio['_latitude'] ?? ubicacionComercio['latitude'])?.toDouble();
        comercioLng = (ubicacionComercio['_longitude'] ?? ubicacionComercio['longitude'])?.toDouble();
      }

      if (comercioLat == null || comercioLng == null) return 0.0;

      // Calcular distancia usando fórmula Haversine
      return _calcularDistanciaHaversine(userLat, userLng, comercioLat, comercioLng);
    } catch (e) {
      print('Error calculando distancia: $e');
      return 0.0;
    }
  }

  double _calcularDistanciaHaversine(double lat1, double lon1, double lat2, double lon2) {
    const double radioTierra = 6371; // Radio de la Tierra en kilómetros
    
    final double dLat = _gradosARadianes(lat2 - lat1);
    final double dLon = _gradosARadianes(lon2 - lon1);
    
    final double a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_gradosARadianes(lat1)) * cos(_gradosARadianes(lat2)) *
         sin(dLon / 2) * sin(dLon / 2));
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distancia = radioTierra * c;
    
    return double.parse(distancia.toStringAsFixed(1));
  }

  double _gradosARadianes(double grados) {
    return grados * pi / 180;
  }

  void _ordenarServicios() {
    setState(() {
      if (_ordenPor == 'Precio') {
        _serviciosEncontrados.sort((a, b) => a['precio'].compareTo(b['precio']));
      } else if (_ordenPor == 'Distancia') {
        _serviciosEncontrados.sort((a, b) => a['distancia'].compareTo(b['distancia']));
      } else if (_ordenPor == 'Rating') {
        _serviciosEncontrados.sort((a, b) => b['rating'].compareTo(a['rating']));
      }
    });
  }

  // Obtener el servicio con mejor precio
  Map<String, dynamic>? _getMejorPrecio() {
    if (_serviciosEncontrados.isEmpty) return null;
    return _serviciosEncontrados.reduce((a, b) => 
      a['precio'] < b['precio'] ? a : b
    );
  }

  // Obtener el servicio más cercano
  Map<String, dynamic>? _getMasCercano() {
    if (_serviciosEncontrados.isEmpty) return null;
    return _serviciosEncontrados.reduce((a, b) => 
      a['distancia'] < b['distancia'] ? a : b
    );
  }

  // Obtener el servicio con mejor rating
  Map<String, dynamic>? _getMejorRating() {
    if (_serviciosEncontrados.isEmpty) return null;
    return _serviciosEncontrados.reduce((a, b) => 
      a['rating'] > b['rating'] ? a : b
    );
  }

  // Calcular ahorro respecto al precio más alto
  double _calcularAhorro(double precioActual) {
    if (_serviciosEncontrados.isEmpty) return 0;
    final precioMax = _serviciosEncontrados.map((s) => s['precio'] as double).reduce(max);
    return precioMax - precioActual;
  }

  Widget _buildResumenComparativo() {
    final mejorPrecio = _getMejorPrecio();
    final masCercano = _getMasCercano();
    final totalOpciones = _serviciosEncontrados.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryOrange.withOpacity(0.2),
            AppTheme.primaryOrange.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryOrange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen Comparativo',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$totalOpciones ${totalOpciones == 1 ? "opción encontrada" : "opciones encontradas"}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.dividerColor, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ResumenItem(
                  icono: Icons.euro,
                  titulo: 'Mejor Precio',
                  valor: mejorPrecio != null 
                    ? '€${mejorPrecio['precio'].toStringAsFixed(2)}'
                    : '-',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ResumenItem(
                  icono: Icons.near_me,
                  titulo: 'Más Cerca',
                  valor: masCercano != null 
                    ? '${masCercano['distancia'].toStringAsFixed(1)} km'
                    : '-',
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Comparar: ${widget.servicioNombre}',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Resumen comparativo
          if (_serviciosEncontrados.isNotEmpty) _buildResumenComparativo(),
          
          // Filtros de ordenamiento
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: _opcionesOrden.map((opcion) {
                final isSelected = _ordenPor == opcion;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _ordenPor = opcion);
                      _ordenarServicios();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryOrange : AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            opcion,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Lista de servicios encontrados
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryOrange,
                    ),
                  )
                : _serviciosEncontrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 80,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No se encontraron servicios',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _serviciosEncontrados.length,
                        itemBuilder: (context, index) {
                          final item = _serviciosEncontrados[index];
                          final servicio = item['servicio'] as Map<String, dynamic>;
                          final comercio = item['comercio'] as Map<String, dynamic>;

                          final mejorPrecio = _getMejorPrecio();
                          final masCercano = _getMasCercano();
                          final mejorRating = _getMejorRating();
                          final ahorro = _calcularAhorro(item['precio']);

                          return _ServicioCard(
                            servicio: servicio,
                            comercio: comercio,
                            precio: item['precio'],
                            duracion: item['duracion'],
                            distancia: item['distancia'],
                            rating: item['rating'],
                            resenas: item['resenas'],
                            esMejorPrecio: mejorPrecio != null && 
                              item['servicio']['id'] == mejorPrecio['servicio']['id'],
                            esMasCercano: masCercano != null && 
                              item['servicio']['id'] == masCercano['servicio']['id'],
                            esMejorRating: mejorRating != null && 
                              item['rating'] == mejorRating['rating'] && 
                              item['rating'] >= 4.5,
                            ahorro: ahorro,
                            onTap: () {
                              // Navegar al calendario con toda la información necesaria
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CalendarPage(
                                    mode: 'booking', // Modo reserva
                                    comercioId: comercio['id'],
                                    salonName: comercio['nombre'] ?? 'Salón',
                                    servicioId: servicio['id'],
                                    servicios: [servicio], // Pasar el servicio seleccionado
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ServicioCard extends StatelessWidget {
  final Map<String, dynamic> servicio;
  final Map<String, dynamic> comercio;
  final double precio;
  final int duracion;
  final double distancia;
  final double rating;
  final int resenas;
  final bool esMejorPrecio;
  final bool esMasCercano;
  final bool esMejorRating;
  final double ahorro;
  final VoidCallback onTap;

  const _ServicioCard({
    required this.servicio,
    required this.comercio,
    required this.precio,
    required this.duracion,
    required this.distancia,
    required this.rating,
    required this.resenas,
    this.esMejorPrecio = false,
    this.esMasCercano = false,
    this.esMejorRating = false,
    this.ahorro = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fotoUrl = comercio['foto_portada'] ?? comercio['foto_url'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del salón con badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: fotoUrl != null && fotoUrl.isNotEmpty
                      ? Image.network(
                          fotoUrl,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 180,
                              color: AppTheme.darkBackground,
                              child: const Icon(
                                Icons.store,
                                size: 60,
                                color: AppTheme.textSecondary,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: double.infinity,
                          height: 180,
                          color: AppTheme.darkBackground,
                          child: const Icon(
                            Icons.store,
                            size: 60,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                ),
                // Badges superiores
                Positioned(
                  top: 12,
                  left: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (esMejorPrecio)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.euro, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Mejor Precio',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (esMejorPrecio && esMasCercano) const SizedBox(height: 6),
                      if (esMasCercano)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.near_me, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Más Cerca',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Badge de rating
                if (esMejorRating)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Top Rated',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Información
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del salón
                  Text(
                    comercio['nombre'] ?? 'Salón',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Precio destacado
                  Text(
                    '€${precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppTheme.primaryOrange,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Rating, Duración y Distancia
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: AppTheme.primaryOrange,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$rating ($resenas reseñas)',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.access_time,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$duracion min',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.location_on,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${distancia.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Indicador de ahorro
                  if (ahorro > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.savings_outlined,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ahorras €${ahorro.toStringAsFixed(2)} vs. opción más cara',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (ahorro > 0) const SizedBox(height: 16),
                  if (ahorro == 0) const SizedBox(height: 16),

                  // Botón de reservar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Reservar Ahora',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para mostrar items del resumen
class _ResumenItem extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;

  const _ResumenItem({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icono,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
