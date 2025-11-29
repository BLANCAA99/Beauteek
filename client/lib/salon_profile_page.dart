import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'calendar_page.dart';
import 'galeria_salon_page.dart';
import 'review_screen.dart';

class SalonProfilePage extends StatefulWidget {
  final String comercioId;

  const SalonProfilePage({
    Key? key,
    required this.comercioId,
  }) : super(key: key);

  @override
  State<SalonProfilePage> createState() => _SalonProfilePageState();
}

class _SalonProfilePageState extends State<SalonProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _comercioData;
  List<Map<String, dynamic>> _servicios = [];
  List<Map<String, dynamic>> _resenas = [];
  List<Map<String, dynamic>> _promociones = [];
  bool _isFavorite = false;
  String? _favoritoId;

  @override
  void initState() {
    super.initState();
    _cargarDatosComercio();
    _verificarFavorito();
    _cargarPromociones();
  }

  // ===================== LÓGICA (NO TOCADA) =====================

  Future<void> _cargarDatosComercio() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      // ✅ Obtener comercio
      final comercioUrl =
          Uri.parse('$apiBaseUrl/comercios/${widget.comercioId}');

      print('🔍 Cargando comercio: $comercioUrl');

      final comercioResponse = await http.get(
        comercioUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (comercioResponse.statusCode == 200) {
        final comercioData = json.decode(comercioResponse.body);

        // ✅ Obtener foto del propietario del salón
        String? fotoSalon;
        final uidPropietario = comercioData['uid_negocio'] as String?;

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
            );

            if (propietarioResponse.statusCode == 200) {
              final propietarioData = json.decode(propietarioResponse.body);
              fotoSalon = propietarioData['foto_url'] as String?;
            }
          } catch (e) {
            print('⚠️ Error obteniendo foto del propietario: $e');
          }
        }

        // Si se obtuvo foto del propietario, reemplazar en comercioData
        if (fotoSalon != null && fotoSalon.isNotEmpty) {
          comercioData['foto_url'] = fotoSalon;
        }

        // ✅ Usar /api/servicios con query param comercio_id
        final serviciosUrl = Uri.parse(
            '$apiBaseUrl/api/servicios?comercio_id=${widget.comercioId}');

        print('🔍 Cargando servicios: $serviciosUrl');

        final serviciosResponse = await http.get(
          serviciosUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );

        print('📥 Servicios status: ${serviciosResponse.statusCode}');
        print('📥 Servicios body: ${serviciosResponse.body}');

        List<Map<String, dynamic>> servicios = [];
        if (serviciosResponse.statusCode == 200) {
          final List<dynamic> serviciosData =
              json.decode(serviciosResponse.body);
          servicios =
              serviciosData.map((s) => s as Map<String, dynamic>).toList();
        }

        // ✅ NUEVO: Cargar reseñas del comercio
        final resenasUrl = Uri.parse(
            '$apiBaseUrl/api/resenas?comercio_id=${widget.comercioId}');

        print('🔍 Cargando reseñas: $resenasUrl');

        final resenasResponse = await http.get(
          resenasUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );

        List<Map<String, dynamic>> resenas = [];
        double calificacionPromedio = 0.0;

        if (resenasResponse.statusCode == 200) {
          final List<dynamic> resenasData =
              json.decode(resenasResponse.body);

          // Calcular calificación promedio
          if (resenasData.isNotEmpty) {
            double sumaCalificaciones = 0;
            for (var resena in resenasData) {
              sumaCalificaciones +=
                  (resena['calificacion'] as num?)?.toDouble() ?? 0;
            }
            calificacionPromedio = sumaCalificaciones / resenasData.length;
          }

          // Obtener nombre de cada usuario que dejó reseña
          for (var resena in resenasData) {
            final usuarioId = resena['usuario_cliente_id'];
            String nombreUsuario = 'Usuario';
            String? fotoUsuario;

            if (usuarioId != null) {
              try {
                final usuarioUrl =
                    Uri.parse('$apiBaseUrl/api/users/uid/$usuarioId');
                final usuarioResponse = await http.get(
                  usuarioUrl,
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $idToken',
                  },
                );

                if (usuarioResponse.statusCode == 200) {
                  final usuarioData = json.decode(usuarioResponse.body);
                  nombreUsuario =
                      usuarioData['nombre_completo'] ?? 'Usuario';
                  fotoUsuario = usuarioData['foto_url'];
                }
              } catch (e) {
                print('⚠️ Error obteniendo usuario: $e');
              }
            }

            resenas.add({
              ...resena as Map<String, dynamic>,
              'nombre_usuario': nombreUsuario,
              'foto_usuario': fotoUsuario,
            });
          }
        }

        // Actualizar calificación del comercio con el promedio calculado
        if (calificacionPromedio > 0) {
          comercioData['calificacion'] = calificacionPromedio;
        }

        setState(() {
          _comercioData = comercioData;
          _servicios = servicios;
          _resenas = resenas;
          _isLoading = false;
        });

        print('✅ Comercio cargado: ${comercioData['nombre']}');
        print('✅ Servicios cargados: ${servicios.length}');
        print('✅ Reseñas cargadas: ${resenas.length}');
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verificarFavorito() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      final favoritosUrl =
          Uri.parse('$apiBaseUrl/api/favoritos?clienteId=${user.uid}');

      final response = await http.get(
        favoritosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> favoritos = json.decode(response.body);

        // Buscar si este comercio específico está en favoritos
        final favoritoExistente = favoritos.firstWhere(
          (fav) => fav['salon_id'] == widget.comercioId,
          orElse: () => null,
        );

        if (favoritoExistente != null) {
          setState(() {
            _isFavorite = true;
            _favoritoId = favoritoExistente['id'];
          });
        }
      }
    } catch (e) {
      print('❌ Error verificando favorito: $e');
    }
  }

  Future<void> _cargarPromociones() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/promociones/comercio/${widget.comercioId}');

      print('🎁 Cargando promociones del salón: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('📊 Promociones recibidas: ${data.length}');
        
        // Filtrar promociones activas y vigentes
        final now = DateTime.now();
        final promocionesActivas = data.where((promo) {
          if (promo['activo'] != true) return false;
          
          try {
            dynamic fechaFinData = promo['fecha_fin'];
            DateTime fechaFin;
            
            if (fechaFinData is Map && fechaFinData.containsKey('_seconds')) {
              final seconds = fechaFinData['_seconds'] as int;
              fechaFin = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            } else if (fechaFinData is String) {
              fechaFin = DateTime.parse(fechaFinData);
            } else {
              return false;
            }
            
            return fechaFin.isAfter(now);
          } catch (e) {
            print('⚠️ Error parseando fecha de promoción: $e');
            return false;
          }
        }).toList();

        setState(() {
          _promociones = promocionesActivas.cast<Map<String, dynamic>>();
        });

        print('✅ Promociones activas del salón: ${_promociones.length}');
      }
    } catch (e) {
      print('❌ Error cargando promociones: $e');
    }
  }

  void _mostrarFotoCompleta(String fotoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                fotoUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 64,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorito() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      if (_isFavorite && _favoritoId != null) {
        // Eliminar favorito
        final url =
            Uri.parse('$apiBaseUrl/api/favoritos/$_favoritoId');

        final response = await http.delete(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );

        if (response.statusCode == 200) {
          setState(() {
            _isFavorite = false;
            _favoritoId = null;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Eliminado de favoritos'),
                backgroundColor: Colors.grey,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // Agregar favorito
        final url = Uri.parse('$apiBaseUrl/api/favoritos');

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: json.encode({
            'usuario_cliente_id': user.uid,
            'salon_id': widget.comercioId,
          }),
        );

        if (response.statusCode == 201) {
          final responseData = json.decode(response.body);

          setState(() {
            _isFavorite = true;
            _favoritoId = responseData['id'];
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Agregado a favoritos ❤️'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar favoritos'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFEA963A)),
        ),
      );
    }

    if (_comercioData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No se pudo cargar el salón')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfo(),
                const SizedBox(height: 24),
                if (_promociones.isNotEmpty) ...[
                  _buildPromociones(),
                  const SizedBox(height: 24),
                ],
                _buildServicios(),
                const SizedBox(height: 24),
                _buildResenas(),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBookButton(),
    );
  }

  SliverAppBar _buildAppBar() {
    final fotoUrl = _comercioData!['foto_url'] as String?;
    final nombre = _comercioData!['nombre'] ?? 'Salón';

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: const Color(0xFF050507),
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Imagen de fondo
              fotoUrl != null && fotoUrl.isNotEmpty
                  ? Image.network(
                      fotoUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEA963A), Color(0xFFFF6B9D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.store,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
              // Degradado superior e inferior
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black38,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // Botones back y favorito
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _roundIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    _roundIconButton(
                      icon: _isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      onTap: _toggleFavorito,
                      isFilled: _isFavorite,
                    ),
                  ],
                ),
              ),
              // Nombre del salón sobre la imagen
              Positioned(
                left: 20,
                right: 20,
                bottom: 28,
                child: Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isFilled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isFilled ? Colors.white : Colors.black45,
          shape: BoxShape.circle,
          border: isFilled
              ? null
              : Border.all(color: Colors.white.withOpacity(0.6), width: 1),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isFilled ? const Color(0xFFEA963A) : Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfo() {
    final calificacion =
        (_comercioData!['calificacion'] as num?)?.toStringAsFixed(1) ??
            '4.8';
    final direccion =
        _comercioData!['direccion'] ?? 'Dirección no disponible';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating + número de reseñas
          Row(
            children: [
              const Icon(Icons.star,
                  color: Color(0xFFFFB800), size: 20),
              const SizedBox(width: 6),
              Text(
                '$calificacion ',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '(${_resenas.length} opiniones)',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFB0B0B0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dirección
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on,
                  color: Color(0xFFB48CFF), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  direccion,
                  style: const TextStyle(
                    color: Color(0xFFD0C7FF),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Botón de Galería
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GaleriaSalonPage(
                    comercioId: widget.comercioId,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEA963A).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFFEA963A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ver Galería de Fotos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

  Widget _buildServicios() {
    if (_servicios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No hay servicios disponibles',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Servicios',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._servicios.map((servicio) {
          final nombre = servicio['nombre'] ?? '';
          final duracion = servicio['duracion_min'] ?? 0;
          final precio = servicio['precio'];

          final precioTexto = precio is num
              ? 'L ${precio.toStringAsFixed(2)}'
              : 'L 0.00';

          return Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$duracion min',
                        style: const TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  precioTexto,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF9500),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPromociones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Promociones Activas',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _promociones.length,
            itemBuilder: (context, index) {
              final promo = _promociones[index];
              return _PromocionCard(
                promocion: promo,
                onTap: () => _navegarACalendarioConPromocion(promo),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navegarACalendarioConPromocion(Map<String, dynamic> promo) {
    // Crear el objeto de servicio con el descuento aplicado
    final servicioConDescuento = {
      'id': promo['servicio_id'],
      'nombre': promo['servicio_nombre'],
      'precio': promo['precio_con_descuento'],
      'precio_original': promo['precio_original'],
      'duracion': promo['duracion'] ?? 60,
      'descuento': promo['valor'],
      'promocion_id': promo['id'],
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarPage(
          mode: 'booking',
          comercioId: widget.comercioId,
          salonName: _comercioData?['nombre'] ?? 'Salón',
          servicioId: promo['servicio_id'],
          servicios: [servicioConDescuento],
        ),
      ),
    );
  }

  Widget _buildResenas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título + "Ver todas"
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Reseñas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Aquí luego puedes navegar a pantalla de todas las reseñas
                },
                child: const Text(
                  'Ver todas',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFF9500),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_resenas.isEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No hay reseñas aún',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sé la primera persona en dejar una reseña.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ..._resenas.map((resena) {
            final nombre = resena['nombre_usuario'] ?? 'Usuario';
            final comentario = resena['comentario'] ?? '';
            final calificacion =
                (resena['calificacion'] as num?)?.toInt() ?? 0;
            final fotoUsuario = resena['foto_usuario'] as String?;
            final fotoResena = resena['foto_url'] as String?;

            return Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: (fotoUsuario == null ||
                                  fotoUsuario.isEmpty)
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFEA963A),
                                    Color(0xFFFF6B9D)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          image: (fotoUsuario != null &&
                                  fotoUsuario.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(fotoUsuario),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (fotoUsuario == null ||
                                fotoUsuario.isEmpty)
                            ? Center(
                                child: Text(
                                  nombre
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children:
                                  List.generate(5, (index) {
                                return Icon(
                                  index < calificacion
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: const Color(0xFFFFB800),
                                  size: 16,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (comentario.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      comentario,
                      style: const TextStyle(
                        color: Color(0xFFDDDDDD),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (fotoResena != null && fotoResena.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _mostrarFotoCompleta(fotoResena),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          fotoResena,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 200,
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 48,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildBookButton() {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF050507),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón "Dejar una reseña" (outline)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                // Navegar a pantalla de crear reseña
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewScreen(
                      citaId: '', // No requiere cita específica para reseña general
                      comercioId: widget.comercioId,
                      salonName: _comercioData!['nombre'] ?? 'Salón',
                      servicioId: _servicios.isNotEmpty ? _servicios.first['id'].toString() : '',
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: Color(0xFFFF9500), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Dejar una reseña',
                style: TextStyle(
                  color: Color(0xFFFF9500),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Botón principal "Agendar Cita" (pill con degradado)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CalendarPage(
                    mode: 'booking',
                    comercioId: widget.comercioId,
                    salonName: _comercioData!['nombre'],
                    servicios: _servicios,
                  ),
                ),
              );
            },
            child: Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9500), Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Agendar Cita',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget para mostrar cada promoción en horizontal scroll
class _PromocionCard extends StatelessWidget {
  final Map<String, dynamic> promocion;
  final VoidCallback onTap;

  const _PromocionCard({
    required this.promocion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final descuento = promocion['valor'] ?? 0;
    final fotoUrl = promocion['foto_url'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen con badge de descuento
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: fotoUrl != null && fotoUrl.isNotEmpty
                      ? Image.network(
                          fotoUrl,
                          width: double.infinity,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 140,
                              color: const Color(0xFF2C2C2E),
                              child: const Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: Color(0xFF9E9E9E),
                              ),
                            );
                          },
                        )
                      : Container(
                          width: double.infinity,
                          height: 140,
                          color: const Color(0xFF2C2C2E),
                          child: const Icon(
                            Icons.image_outlined,
                            size: 40,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFEA963A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '-$descuento%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Información
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promocion['servicio_nombre'] ?? 'Servicio',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (promocion['precio_original'] != null)
                        Text(
                          'L ${promocion['precio_original']}',
                          style: const TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        'L ${promocion['precio_con_descuento'] ?? '0.00'}',
                        style: const TextStyle(
                          color: Color(0xFFFF9500),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
  }
}