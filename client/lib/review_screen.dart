import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'api_constants.dart';

class ReviewScreen extends StatefulWidget {
  final String citaId;
  final String comercioId;
  final String salonName;
  final String servicioId;

  const ReviewScreen({
    Key? key,
    required this.citaId,
    required this.comercioId,
    required this.salonName,
    required this.servicioId,
  }) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isLoading = false;
  XFile? _selectedImage;
  bool _isUploadingImage = false;
  
  final ImagePicker _picker = ImagePicker();
  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    'dskg1hw9n',
    'Imagenes_Beauteek',
    cache: false,
  );

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto() async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Seleccionar foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFEA963A)),
                title: const Text('Cámara'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFEA963A)),
                title: const Text('Galería'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _eliminarFoto() {
    setState(() => _selectedImage = null);
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una calificación'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final idToken = await user.getIdToken();

      // Subir foto a Cloudinary si existe
      String? fotoUrl;
      if (_selectedImage != null) {
        setState(() => _isUploadingImage = true);
        
        try {
          final response = await _cloudinary.uploadFile(
            CloudinaryFile.fromFile(
              _selectedImage!.path,
              folder: 'resenas',
            ),
          );
          fotoUrl = response.secureUrl;
          print('✅ Foto subida a Cloudinary: $fotoUrl');
        } catch (e) {
          print('⚠️ Error subiendo foto: $e');
          // Continuar sin foto si falla
        } finally {
          if (mounted) {
            setState(() => _isUploadingImage = false);
          }
        }
      }

      // ✅ Primero obtener el uid_negocio del comercio
      final comercioUrl = Uri.parse('$apiBaseUrl/comercios/${widget.comercioId}');
      final comercioResponse = await http.get(
        comercioUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (comercioResponse.statusCode != 200) {
        throw Exception('No se pudo obtener información del comercio');
      }

      final comercioData = json.decode(comercioResponse.body);
      final uidNegocio = comercioData['uid_negocio'];

      if (uidNegocio == null) {
        throw Exception('No se encontró el UID del negocio');
      }

      // ✅ CAMBIO: Usar API en lugar de Firestore
      final payload = {
        'cita_id': widget.citaId,
        'comercio_id': widget.comercioId,
        'servicio_id': widget.servicioId,
        'usuario_cliente_id': user.uid,
        'usuario_salon_id': uidNegocio,
        'calificacion': _rating,
        'comentario': _commentController.text.trim(),
        if (fotoUrl != null) 'foto_url': fotoUrl,
      };

      final url = Uri.parse('$apiBaseUrl/api/resenas');
      print('📤 Enviando reseña: ${json.encode(payload)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(payload),
      );

      print('📥 Response: ${response.statusCode}');

      if (response.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reseña enviada correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error enviando reseña: $e');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Dejar reseña',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA963A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del salón
                  Text(
                    widget.salonName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '¿Cómo fue tu experiencia?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Estrellas
                  const Text(
                    'Calificación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setState(() => _rating = index + 1),
                          child: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFFFB800),
                            size: 48,
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Comentario
                  const Text(
                    'Comentario (opcional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Cuéntanos sobre tu experiencia...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFEA963A),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Foto opcional
                  const Text(
                    'Foto (opcional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (_selectedImage != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_selectedImage!.path),
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                            onPressed: _eliminarFoto,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  OutlinedButton.icon(
                    onPressed: _isUploadingImage ? null : _seleccionarFoto,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: Text(_selectedImage == null 
                      ? 'Agregar foto del servicio' 
                      : 'Cambiar foto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEA963A),
                      side: const BorderSide(color: Color(0xFFEA963A)),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botón enviar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA963A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Enviar reseña',
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
            ),
    );
  }
}
