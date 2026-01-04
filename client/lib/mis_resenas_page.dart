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

  // Colores de tema oscuro tipo mockup
  static const Color _backgroundColor = Color(0xFF18100A);
  static const Color _cardColor = Color(0xFF24170F);
  static const Color _primaryOrange = Color(0xFFEA963A);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB7AEA5);

  @override
  void initState() {
    super.initState();
    _cargarMisResenas();
  }

  // 🔹 LÓGICA ORIGINAL (NO TOCADA)
  Future<void> _cargarMisResenas() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      // Obtener reseñas del usuario
      final resenasUrl = Uri.parse(
          '$apiBaseUrl/api/resenas?usuario_cliente_id=${user.uid}');
      final resenasResponse = await http.get(
        resenasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (resenasResponse.statusCode == 200) {
        final List<dynamic> resenasData =
            json.decode(resenasResponse.body);

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
              final usuarioUrl =
                  Uri.parse('$apiBaseUrl/api/users/uid/$usuarioSalonId');
              final usuarioResponse = await http.get(
                usuarioUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
              );

              if (usuarioResponse.statusCode == 200) {
                final usuarioData =
                    json.decode(usuarioResponse.body);
                nombreSalon =
                    usuarioData['nombre_completo'] ?? nombreSalon;
                fotoSalon = usuarioData['foto_url'];
              }
            } catch (e) {
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
      } else {
        setState(() {
          _misResenas = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _misResenas = [];
        _isLoading = false;
      });
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
        centerTitle: true,
        title: const Text(
          'Mis Reseñas',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryOrange),
            )
          : _misResenas.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _misResenas.length,
                  itemBuilder: (context, index) {
                    final resena = _misResenas[index];
                    return _buildResenaCard(resena);
                  },
                ),
    );
  }

  // 🔸 Card de reseña con estilo del mockup
  Widget _buildResenaCard(Map<String, dynamic> resena) {
    final String nombreSalon = resena['nombre_salon'] ?? 'Salón';
    final String servicioNombre =
        resena['servicio_nombre'] ?? 'Servicio'; // si existe
    final int calificacion =
        (resena['calificacion'] as num?)?.toInt() ?? 0;
    final String comentario =
        (resena['comentario'] ?? '').toString().trim();

    // Tomar alguna fecha en texto si viene
    final String fechaTexto =
        (resena['fecha'] ?? resena['fecha_creacion'] ?? '')
            .toString()
            .trim();

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
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título + menú
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreSalon,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Servicio: $servicioNombre',
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(
                      Icons.more_vert,
                      color: _textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Estrellas
              Row(
                children: List.generate(5, (index) {
                  final bool filled = index < calificacion;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: _primaryOrange,
                      size: 22,
                    ),
                  );
                }),
              ),

              if (comentario.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  comentario,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ],

              if (fechaTexto.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  fechaTexto,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Estado vacío adaptado al tema oscuro
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 80,
              color: _textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 18),
            const Text(
              'No has dejado reseñas aún',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Visita un salón y comparte tu experiencia para verla aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}