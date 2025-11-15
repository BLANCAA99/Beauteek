import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'calendar_page.dart';

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
  bool _isFavorite = false;
  String? _favoritoId;

  @override
  void initState() {
    super.initState();
    _cargarDatosComercio();
    _verificarFavorito();
  }

  Future<void> _cargarDatosComercio() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      
      // ✅ Obtener comercio
      final comercioUrl = Uri.parse('$apiBaseUrl/comercios/${widget.comercioId}');
      
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
            final propietarioUrl = Uri.parse('$apiBaseUrl/api/users/uid/$uidPropietario');
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
        
        // ✅ CAMBIO: Usar /api/servicios con query param comercio_id
        final serviciosUrl = Uri.parse('$apiBaseUrl/api/servicios?comercio_id=${widget.comercioId}');
        
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
          final List<dynamic> serviciosData = json.decode(serviciosResponse.body);
          servicios = serviciosData
              .map((s) => s as Map<String, dynamic>)
              .toList();
        }

        // ✅ NUEVO: Cargar reseñas del comercio
        final resenasUrl = Uri.parse('$apiBaseUrl/api/resenas?comercio_id=${widget.comercioId}');
        
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
          final List<dynamic> resenasData = json.decode(resenasResponse.body);
          
          // Calcular calificación promedio
          if (resenasData.isNotEmpty) {
            double sumaCalificaciones = 0;
            for (var resena in resenasData) {
              sumaCalificaciones += (resena['calificacion'] as num?)?.toDouble() ?? 0;
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
                final usuarioUrl = Uri.parse('$apiBaseUrl/api/users/uid/$usuarioId');
                final usuarioResponse = await http.get(
                  usuarioUrl,
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $idToken',
                  },
                );
                
                if (usuarioResponse.statusCode == 200) {
                  final usuarioData = json.decode(usuarioResponse.body);
                  nombreUsuario = usuarioData['nombre_completo'] ?? 'Usuario';
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
      
      final favoritosUrl = Uri.parse('$apiBaseUrl/api/favoritos?clienteId=${user.uid}');
      
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

  Future<void> _toggleFavorito() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      
      if (_isFavorite && _favoritoId != null) {
        // Eliminar favorito
        final url = Uri.parse('$apiBaseUrl/api/favoritos/$_favoritoId');
        
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFEA963A)),
        ),
      );
    }

    if (_comercioData == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Error')),
        body: Center(child: Text('No se pudo cargar el salón')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfo(),
                _buildServicios(),
                _buildResenas(),
                SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBookButton(),
    );
  }

  Widget _buildAppBar() {
    final fotoUrl = _comercioData!['foto_url'] as String?;
    
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      actions: [
        IconButton(
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : Colors.white,
            size: 28,
          ),
          onPressed: _toggleFavorito,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: fotoUrl != null && fotoUrl.isNotEmpty
            ? Image.network(fotoUrl, fit: BoxFit.cover)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEA963A), Color(0xFFFF6B9D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(Icons.store, size: 80, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _comercioData!['nombre'] ?? 'Salón',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.star, color: Color(0xFFFFB800), size: 20),
              SizedBox(width: 4),
              Text(
                '${_comercioData!['calificacion'] ?? 4.5}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _comercioData!['direccion'] ?? 'Dirección no disponible',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicios() {
    if (_servicios.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(20),
        child: Text('No hay servicios disponibles'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Servicios',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 12),
        ..._servicios.map((servicio) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        servicio['nombre'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${servicio['duracion_min']} min',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Text(
                  'L${servicio['precio']?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEA963A),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildResenas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(
                'Reseñas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFEA963A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_resenas.length}',
                  style: TextStyle(
                    color: Color(0xFFEA963A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_resenas.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No hay reseñas aún',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sé el primero en dejar una reseña',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._resenas.map((resena) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar con foto o inicial
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: resena['foto_usuario'] == null || (resena['foto_usuario'] as String).isEmpty
                              ? LinearGradient(
                                  colors: [Color(0xFFEA963A), Color(0xFFFF6B9D)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          image: resena['foto_usuario'] != null && (resena['foto_usuario'] as String).isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(resena['foto_usuario']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: resena['foto_usuario'] == null || (resena['foto_usuario'] as String).isEmpty
                            ? Center(
                                child: Text(
                                  (resena['nombre_usuario'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: 12),
                      // Nombre y estrellas
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resena['nombre_usuario'] ?? 'Usuario',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: List.generate(5, (index) {
                                final calificacion = (resena['calificacion'] as num?)?.toInt() ?? 0;
                                return Icon(
                                  index < calificacion ? Icons.star : Icons.star_border,
                                  color: Color(0xFFFFB800),
                                  size: 18,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (resena['comentario'] != null && (resena['comentario'] as String).isNotEmpty) ...[
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        resena['comentario'],
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          height: 1.5,
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
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
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
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFEA963A),
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Agendar cita',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
