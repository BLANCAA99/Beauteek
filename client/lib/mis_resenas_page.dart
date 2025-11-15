import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'salon_profile_page.dart';

class MisResenasPage extends StatefulWidget {
  const MisResenasPage({Key? key}) : super(key: key);

  @override
  State<MisResenasPage> createState() => _MisResenasPageState();
}

class _MisResenasPageState extends State<MisResenasPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _misResenas = [];

  @override
  void initState() {
    super.initState();
    _cargarMisResenas();
  }

  Future<void> _cargarMisResenas() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      
      // Obtener reseñas del usuario
      final resenasUrl = Uri.parse('$apiBaseUrl/api/resenas?usuario_cliente_id=${user.uid}');
      
      print('🔍 Cargando mis reseñas: $resenasUrl');
      
      final resenasResponse = await http.get(
        resenasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (resenasResponse.statusCode == 200) {
        final List<dynamic> resenasData = json.decode(resenasResponse.body);
        
        // Obtener nombre del salón para cada reseña
        final List<Map<String, dynamic>> resenasConSalon = [];
        for (var resena in resenasData) {
          final resenaMap = resena as Map<String, dynamic>;
          final usuarioSalonId = resenaMap['usuario_salon_id'];
          
          String nombreSalon = 'Salón';
          String? fotoSalon;
          
          // Obtener nombre del usuario salón
          if (usuarioSalonId != null) {
            try {
              final usuarioUrl = Uri.parse('$apiBaseUrl/api/users/uid/$usuarioSalonId');
              final usuarioResponse = await http.get(
                usuarioUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
              );
              
              if (usuarioResponse.statusCode == 200) {
                final usuarioData = json.decode(usuarioResponse.body);
                nombreSalon = usuarioData['nombre_completo'] ?? nombreSalon;
                fotoSalon = usuarioData['foto_url'];
              }
            } catch (e) {
              print('⚠️ Error obteniendo usuario salón: $e');
            }
          }
          
          resenasConSalon.add({
            ...resenaMap,
            'nombre_salon': nombreSalon,
            'foto_salon': fotoSalon,
          });
        }
        
        setState(() {
          _misResenas = resenasConSalon;
          _isLoading = false;
        });
        
        print('✅ ${_misResenas.length} reseñas cargadas');
      } else {
        setState(() {
          _misResenas = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _misResenas = [];
        _isLoading = false;
      });
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
          'Mis reseñas',
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
          : _misResenas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No has dejado reseñas aún',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Visita un salón y comparte tu experiencia',
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
                  itemCount: _misResenas.length,
                  itemBuilder: (context, index) {
                    final resena = _misResenas[index];
                    
                    return GestureDetector(
                      onTap: () {
                        if (resena['comercio_id'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SalonProfilePage(
                                comercioId: resena['comercio_id'],
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Foto del salón
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: resena['foto_salon'] == null || (resena['foto_salon'] as String).isEmpty
                                        ? const LinearGradient(
                                            colors: [Color(0xFFEA963A), Color(0xFFFF6B9D)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    image: resena['foto_salon'] != null && (resena['foto_salon'] as String).isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(resena['foto_salon']),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: resena['foto_salon'] == null || (resena['foto_salon'] as String).isEmpty
                                      ? const Icon(Icons.store, color: Colors.white, size: 28)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // Nombre y estrellas
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        resena['nombre_salon'] ?? 'Salón',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: List.generate(5, (starIndex) {
                                          final calificacion = (resena['calificacion'] as num?)?.toInt() ?? 0;
                                          return Icon(
                                            starIndex < calificacion ? Icons.star : Icons.star_border,
                                            color: const Color(0xFFFFB800),
                                            size: 20,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                            if (resena['comentario'] != null && (resena['comentario'] as String).isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
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
                      ),
                    );
                  },
                ),
    );
  }
}
