import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'api_constants.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfilePage({Key? key, required this.userData}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _photoUrlController;
  late TextEditingController _dobController; // Fecha de Nacimiento
  String? _selectedGender;                   // Género

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;   // Guardar
  bool _isFetching = false;  // Carga inicial

  @override
  void initState() {
    super.initState();

    // Prefill rápido con lo que venga en userData (si llega algo)
    final firstName = widget.userData['firstName'] ?? '';
    final lastName  = widget.userData['lastName']  ?? '';
    final nombreCompleto = '$firstName $lastName'.trim();
    final finalName = nombreCompleto.isNotEmpty
        ? nombreCompleto
        : (widget.userData['nombre_completo'] ?? '');

    _nameController     = TextEditingController(text: finalName);
    _phoneController    = TextEditingController(text: widget.userData['phone'] ?? widget.userData['telefono'] ?? '');
    _addressController  = TextEditingController(text: widget.userData['direccion'] ?? '');
    _photoUrlController = TextEditingController(text: widget.userData['photoURL'] ?? widget.userData['foto_url'] ?? '');
    _dobController      = TextEditingController(text: widget.userData['fecha_nacimiento'] ?? '');
    _selectedGender     = widget.userData['genero'];
    _cargarUsuarioDeApi();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _photoUrlController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarioDeApi() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isFetching = true);

    try {
      final idToken = await user.getIdToken(); // quítalo si tu API no valida token
      final url = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');

      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (resp.statusCode == 200) {
        // Tu controlador responde plano: { id, ...campos }
        final Map<String, dynamic> data = json.decode(resp.body);

        // Extrae y rellena si hay valores
        final nombre = (data['nombre_completo'] ?? '').toString();
        final tel    = (data['telefono'] ?? '').toString();
        final dir    = (data['direccion'] ?? '').toString();
        final foto   = (data['foto_url'] ?? '').toString();
        final dob    = (data['fecha_nacimiento'] ?? '').toString();
        final genero = (data['genero'] ?? '').toString();

        if (nombre.isNotEmpty) _nameController.text = nombre;
        if (tel.isNotEmpty)    _phoneController.text = tel;
        if (dir.isNotEmpty)    _addressController.text = dir;
        if (foto.isNotEmpty)   _photoUrlController.text = foto;
        if (dob.isNotEmpty)    _dobController.text = dob;

        if (genero.isNotEmpty) {
          const opciones = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decirlo'];
          _selectedGender = opciones.contains(genero) ? genero : null;
        }

        if (mounted) setState(() {});
      } else {
        // Puedes loguear/avisar si quieres
        // print('GET perfil falló: ${resp.statusCode} - ${resp.body}');
      }
    } catch (e) {
      // print('Error cargando usuario: $e');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  // --- Subir imagen a Cloudinary ---
  Future<void> _pickAndUploadImage() async {
    final XFile? selectedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (selectedImage == null) return;

    setState(() => _isUploading = true);

    final cloudinary = CloudinaryPublic('dskg1hw9n', 'Imagenes_Beauteek', cache: false);
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(selectedImage.path, resourceType: CloudinaryResourceType.Image),
      );

      setState(() {
        _imageFile = selectedImage;
        _photoUrlController.text = response.secureUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen subida con éxito')),
      );
    } on CloudinaryException catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: ${e.message}')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final idToken = await user.getIdToken();

      final url = Uri.parse('$apiBaseUrl/api/users/${user.uid}');

      final Map<String, dynamic> profileData = {
        'nombre_completo': _nameController.text.trim(),
        'telefono': _phoneController.text.trim(),
        'direccion': _addressController.text.trim(),
        'foto_url': _photoUrlController.text.trim(),
        'fecha_nacimiento': _dobController.text.trim(),
        'genero': _selectedGender,
      };

      profileData.removeWhere((k, v) => v == null || (v is String && v.isEmpty));

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(profileData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado con éxito')),
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = (errorData is Map && errorData['message'] != null)
            ? errorData['message'].toString()
            : 'Error al actualizar el perfil.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (_isFetching)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _imageFile != null
                        ? FileImage(File(_imageFile!.path))
                        : (_photoUrlController.text.isNotEmpty
                            ? NetworkImage(_photoUrlController.text)
                            : null) as ImageProvider?,
                    child: _imageFile == null && _photoUrlController.text.isEmpty
                        ? Icon(Icons.person, size: 60, color: Colors.grey.shade400)
                        : null,
                  ),
                  if (_isUploading) const CircularProgressIndicator(),
                  if (!_isUploading)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Por favor, ingresa tu nombre'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Número de teléfono',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Por favor, ingresa tu teléfono'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Por favor, ingresa tu dirección'
                  : null,
            ),
            const SizedBox(height: 16),
            // Fecha de Nacimiento
            TextFormField(
              controller: _dobController,
              decoration: const InputDecoration(
                labelText: 'Fecha de Nacimiento (YYYY-MM-DD)',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                );
                if (pickedDate != null) {
                  setState(() {
                    _dobController.text = pickedDate.toIso8601String().substring(0, 10);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            // Género
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Género',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                DropdownMenuItem(value: 'Prefiero no decirlo', child: Text('Prefiero no decirlo')),
              ],
              onChanged: (value) => setState(() => _selectedGender = value),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }
}