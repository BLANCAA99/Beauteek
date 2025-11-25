import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class GaleriaSalonPage extends StatefulWidget {
  final String comercioId;
  final bool modoSeleccion; // si true, devuelve la URL al caller

  const GaleriaSalonPage({
    Key? key,
    required this.comercioId,
    this.modoSeleccion = false,
  }) : super(key: key);

  @override
  State<GaleriaSalonPage> createState() => _GaleriaSalonPageState();
}

class _GaleriaSalonPageState extends State<GaleriaSalonPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _fotos = [];
  List<Map<String, dynamic>> _servicios = [];
  String? _servicioSeleccionado; // para subir fotos nuevas

  final ImagePicker _picker = ImagePicker();
  bool _subiendoFoto = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      // 1. Traer servicios (MISMA RUTA QUE EN GestionarPromociones y SalonProfilePage)
      final serviciosUrl = Uri.parse(
          '$apiBaseUrl/api/servicios?comercio_id=${widget.comercioId}');
      print('📸 [Galería] Cargando servicios: $serviciosUrl');

      final serviciosResponse = await http.get(
        serviciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (serviciosResponse.statusCode == 200) {
        final List<dynamic> serviciosData =
            json.decode(serviciosResponse.body);
        _servicios =
            serviciosData.map((s) => s as Map<String, dynamic>).toList();
        print('📸 [Galería] Servicios cargados: ${_servicios.length}');
      } else {
        print(
            '❌ [Galería] Error obteniendo servicios: ${serviciosResponse.body}');
      }

      // 2. Traer fotos de la galería
      final fotosUrl = Uri.parse(
          '$apiBaseUrl/api/galeria-fotos/comercio/${widget.comercioId}');
      print('📸 [Galería] Cargando fotos: $fotosUrl');

      final fotosResponse = await http.get(
        fotosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (fotosResponse.statusCode == 200) {
        final List<dynamic> fotosData = json.decode(fotosResponse.body);
        _fotos =
            fotosData.map((f) => f as Map<String, dynamic>).toList();
        print('📸 [Galería] Fotos cargadas: ${_fotos.length}');
      } else {
        print(
            '❌ [Galería] Error obteniendo fotos: ${fotosResponse.body}');
      }

      // Si hay servicios, seleccionamos el primero por defecto (para subir nuevas fotos)
      if (_servicios.isNotEmpty && _servicioSeleccionado == null) {
        _servicioSeleccionado = _servicios.first['id'].toString();
      }
    } catch (e) {
      print('❌ [Galería] Error cargando datos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: const Text(
          'Galería del Salón',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : _fotos.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3 / 4,
                  ),
                  itemCount: _fotos.length,
                  itemBuilder: (context, index) {
                    final foto = _fotos[index];
                    final url = foto['foto_url'] as String?;
                    final servicioNombre =
                        foto['servicio_nombre'] ?? 'Servicio';

                    return GestureDetector(
                      onTap: () {
                        if (widget.modoSeleccion && url != null) {
                          // 👈 Devolver URL a quien llamó (promociones)
                          Navigator.pop(context, url);
                        } else if (url != null) {
                          _mostrarFotoCompleta(url);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: url != null
                                    ? Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error,
                                            stackTrace) {
                                          return Container(
                                            color: AppTheme.darkBackground,
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: AppTheme.textSecondary,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: AppTheme.darkBackground,
                                        child: const Icon(
                                          Icons.image,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                servicioNombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: widget.modoSeleccion
          ? null // en modo selección no se suben fotos nuevas
          : FloatingActionButton(
              backgroundColor: AppTheme.primaryOrange,
              onPressed: _servicios.isEmpty
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'No hay servicios disponibles. Agrega servicios primero.'),
                          backgroundColor: AppTheme.primaryOrange,
                        ),
                      );
                    }
                  : _mostrarFormularioNuevaFoto,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      bottomNavigationBar: (!_isLoading && _servicios.isEmpty)
          ? Container(
              padding: const EdgeInsets.all(12),
              color: AppTheme.primaryOrange,
              child: const Text(
                'No hay servicios disponibles. Agrega servicios primero.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_outlined,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No se encontraron fotos en la galería',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toca el botón + para agregar',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarFotoCompleta(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ============ SUBIR FOTO (Cloudinary + API) ============

  Future<void> _subirFotoServicio(BuildContext sheetContext) async {
    if (_servicioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un servicio primero'),
          backgroundColor: AppTheme.primaryOrange,
        ),
      );
      return;
    }

    try {
      // 1. Elegir foto desde la galería del celular
      final XFile? selectedImage =
          await _picker.pickImage(source: ImageSource.gallery);

      if (selectedImage == null) {
        return; // usuario canceló
      }

      setState(() => _subiendoFoto = true);

      // 2. Subir a Cloudinary (mismo config que EditProfilePage)
      final cloudinary = CloudinaryPublic(
        'dskg1hw9n',        // 👈 tu cloud name
        'Imagenes_Beauteek', // 👈 tu upload preset / folder
        cache: false,
      );

      final uploadResponse = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          selectedImage.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      final fotoUrl = uploadResponse.secureUrl;
      print('✅ [Galería] Imagen subida a Cloudinary: $fotoUrl');

      // 3. Guardar registro en tu API /api/galeria-fotos
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _subiendoFoto = false);
        return;
      }

      final idToken = await user.getIdToken();

      // Buscar el servicio seleccionado para obtener nombre
      final servicio = _servicios.firstWhere(
        (s) => s['id'].toString() == _servicioSeleccionado,
        orElse: () => {},
      );
      final servicioNombre = servicio['nombre'] ?? 'Servicio';

      final body = {
        'comercio_id': widget.comercioId,
        'servicio_id': _servicioSeleccionado,
        'servicio_nombre': servicioNombre,
        'foto_url': fotoUrl,
      };

      final url = Uri.parse('$apiBaseUrl/api/galeria-fotos');
      print('🌐 [Galería] Guardando foto en API: $url');
      print('📦 Payload: ${json.encode(body)}');

      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(body),
      );

      print('📡 [Galería] Status guardar foto: ${resp.statusCode}');
      print('📄 [Galería] Body: ${resp.body}');

      if (resp.statusCode == 201 || resp.statusCode == 200) {
        // cerrar sheet
        Navigator.pop(sheetContext);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto agregada a la galería'),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _cargarDatos();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error al guardar la foto en la galería (${resp.statusCode})'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [Galería] Error subiendo foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir la foto: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  // ============ BOTTOM SHEET NUEVA FOTO ============

  Future<void> _mostrarFormularioNuevaFoto() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nueva foto',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Servicio',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _servicioSeleccionado,
                dropdownColor: AppTheme.darkBackground,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                items: _servicios
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s['id'].toString(),
                        child: Text(s['nombre'] ?? 'Servicio'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _servicioSeleccionado = value);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _subiendoFoto
                      ? null
                      : () => _subirFotoServicio(sheetContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _subiendoFoto
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Subir foto',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}