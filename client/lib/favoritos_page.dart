import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'salon_profile_page.dart';

class FavoritosPage extends StatefulWidget {
  const FavoritosPage({Key? key}) : super(key: key);

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _favoritos = [];

  static const Color _backgroundColor = Color(0xFF18100A);
  static const Color _cardColor = Color(0xFF24170F);
  static const Color _primaryOrange = Color(0xFFEA963A);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB7AEA5);

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  Future<void> _cargarFavoritos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      // Obtener favoritos del usuario
      final favoritosUrl =
          Uri.parse('$apiBaseUrl/api/favoritos?clienteId=${user.uid}');

      print('🔍 Cargando favoritos: $favoritosUrl');

      final favoritosResponse = await http.get(
        favoritosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (favoritosResponse.statusCode == 200) {
        final List<dynamic> favoritosData =
            json.decode(favoritosResponse.body);

        // Obtener datos del comercio para cada favorito
        final List<Map<String, dynamic>> favoritosConDatos = [];
        for (var favorito in favoritosData) {
          final favoritoMap = favorito as Map<String, dynamic>;
          final comercioId = favoritoMap['salon_id'];

          if (comercioId != null) {
            try {
              final comercioUrl =
                  Uri.parse('$apiBaseUrl/comercios/$comercioId');
              final comercioResponse = await http.get(
                comercioUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
              );

              if (comercioResponse.statusCode == 200) {
                final comercioData =
                    json.decode(comercioResponse.body);

                // Obtener foto del propietario
                final uidPropietario =
                    comercioData['uid_negocio'] as String?;
                String? fotoSalon;

                if (uidPropietario != null) {
                  try {
                    final propietarioUrl = Uri.parse(
                        '$apiBaseUrl/api/users/uid/$uidPropietario');
                    final propietarioResponse = await http.get(
                      propietarioUrl,
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $idToken',
                      },
                    );

                    if (propietarioResponse.statusCode == 200) {
                      final propietarioData =
                          json.decode(propietarioResponse.body);
                      fotoSalon =
                          propietarioData['foto_url'] as String?;
                    }
                  } catch (e) {
                    print('⚠️ Error obteniendo foto: $e');
                  }
                }

                favoritosConDatos.add({
                  'favorito_id': favoritoMap['id'],
                  'comercio_id': comercioId,
                  'nombre': comercioData['nombre'],
                  'foto_url': fotoSalon,
                  'direccion': comercioData['direccion'],
                  'calificacion': comercioData['calificacion'],
                });
              }
            } catch (e) {
              print('⚠️ Error obteniendo comercio: $e');
            }
          }
        }

        setState(() {
          _favoritos = favoritosConDatos;
          _isLoading = false;
        });

        print('✅ ${_favoritos.length} favoritos cargados');
      } else {
        setState(() {
          _favoritos = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _favoritos = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _eliminarFavorito(String favoritoId, int index) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      final url = Uri.parse('$apiBaseUrl/api/favoritos/$favoritoId');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _favoritos.removeAt(index);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Eliminado de favoritos'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error eliminando favorito: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: const BackButton(color: _textPrimary),
        title: const Text(
          'Favoritos',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Icon(Icons.more_vert, color: _textPrimary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryOrange),
            )
          : _favoritos.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _favoritos.length,
                        itemBuilder: (context, index) {
                          final favorito = _favoritos[index];
                          return _buildFavoritoCard(favorito, index);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  // Barra de búsqueda (solo visual, sin lógica extra)
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        readOnly: true,
        decoration: InputDecoration(
          hintText: 'Buscar en favoritos...',
          hintStyle: const TextStyle(color: _textSecondary),
          prefixIcon: const Icon(Icons.search, color: _textSecondary),
          filled: true,
          fillColor: const Color(0xFF26180F),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Card de favorito estilo mockup
  Widget _buildFavoritoCard(Map<String, dynamic> favorito, int index) {
    final String nombre = favorito['nombre'] ?? 'Salón';
    final String direccion = (favorito['direccion'] ?? '') as String;
    final calificacion = favorito['calificacion'] ?? 4.5;

    // De la dirección tomamos algo corto tipo “Polanco, CDMX”
    String ubicacion = direccion;
    if (direccion.contains(',')) {
      final parts = direccion.split(',');
      if (parts.length >= 2) {
        ubicacion = '${parts[0].trim()}, ${parts[1].trim()}';
      }
    }

    final fotoUrl = favorito['foto_url'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SalonProfilePage(
              comercioId: favorito['comercio_id'],
            ),
          ),
        ).then((_) => _cargarFavoritos());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Foto
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF332015),
                    gradient: (fotoUrl == null || fotoUrl.isEmpty)
                        ? const LinearGradient(
                            colors: [Color(0xFFEA963A), Color(0xFFFFB46B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                  ),
                  child: (fotoUrl != null && fotoUrl.isNotEmpty)
                      ? Image.network(
                          fotoUrl,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.store,
                          color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 16, color: Color(0xFFFFB800)),
                        const SizedBox(width: 4),
                        Text(
                          '$calificacion',
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '•',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ubicacion,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Botón corazón
              IconButton(
                icon: const Icon(
                  Icons.favorite,
                  // Si quieres que se vea contorno usa Icons.favorite_border
                  color: _primaryOrange,
                ),
                onPressed: () {
                  _eliminarFavorito(favorito['favorito_id'], index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Estado vacío tipo mockup
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Círculo con corazón
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: Color(0xFF28190F),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.favorite_border,
                size: 56,
                color: _primaryOrange,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Guarda tus salones preferidos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Toca el ícono del corazón en cualquier salón para verlo aquí más tarde.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // volver a explorar salones
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryOrange,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Explorar Salones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}