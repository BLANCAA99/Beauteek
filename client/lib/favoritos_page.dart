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
      final favoritosUrl = Uri.parse('$apiBaseUrl/api/favoritos?clienteId=${user.uid}');
      
      print('🔍 Cargando favoritos: $favoritosUrl');
      
      final favoritosResponse = await http.get(
        favoritosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (favoritosResponse.statusCode == 200) {
        final List<dynamic> favoritosData = json.decode(favoritosResponse.body);
        
        // Obtener datos del comercio para cada favorito
        final List<Map<String, dynamic>> favoritosConDatos = [];
        for (var favorito in favoritosData) {
          final favoritoMap = favorito as Map<String, dynamic>;
          final comercioId = favoritoMap['salon_id'];
          
          if (comercioId != null) {
            try {
              final comercioUrl = Uri.parse('$apiBaseUrl/comercios/$comercioId');
              final comercioResponse = await http.get(
                comercioUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
              );
              
              if (comercioResponse.statusCode == 200) {
                final comercioData = json.decode(comercioResponse.body);
                
                // Obtener foto del propietario
                final uidPropietario = comercioData['uid_negocio'] as String?;
                String? fotoSalon;
                
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'Favoritos',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFEA963A)),
            )
          : _favoritos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes favoritos aún',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Marca tus salones favoritos con ❤️',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favoritos.length,
                  itemBuilder: (context, index) {
                    final favorito = _favoritos[index];
                    
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
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Foto del salón
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: favorito['foto_url'] == null || (favorito['foto_url'] as String).isEmpty
                                      ? const LinearGradient(
                                          colors: [Color(0xFFEA963A), Color(0xFFFF6B9D)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  image: favorito['foto_url'] != null && (favorito['foto_url'] as String).isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(favorito['foto_url']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: favorito['foto_url'] == null || (favorito['foto_url'] as String).isEmpty
                                    ? const Icon(Icons.store, color: Colors.white, size: 40)
                                    : null,
                              ),
                            ),
                            // Info del salón
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      favorito['nombre'] ?? 'Salón',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${favorito['calificacion'] ?? 4.5}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (favorito['direccion'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        favorito['direccion'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            // Botón eliminar
                            IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.red),
                              onPressed: () {
                                _eliminarFavorito(favorito['favorito_id'], index);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
