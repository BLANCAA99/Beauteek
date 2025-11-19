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
  String? _selectedGender; // Género

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // Guardar
  bool _isFetching = false; // Carga inicial

  // 🎨 Colores de la pantalla tipo Beauteek
  static const Color _backgroundColor = Color(0xFF120D07);
  static const Color _cardColor = Color(0xFF25201A);
  static const Color _fieldColor = Color(0xFF25201A);
  static const Color _primaryOrange = Color(0xFFEA963A);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB3ACA5);

  @override
  void initState() {
    super.initState();

    // Prefill rápido con lo que venga en userData (si llega algo)
    final firstName = widget.userData['firstName'] ?? '';
    final lastName = widget.userData['lastName'] ?? '';
    final nombreCompleto = '$firstName $lastName'.trim();
    final finalName = nombreCompleto.isNotEmpty
        ? nombreCompleto
        : (widget.userData['nombre_completo'] ?? '');

    _nameController = TextEditingController(text: finalName);
    _phoneController = TextEditingController(
        text: widget.userData['phone'] ?? widget.userData['telefono'] ?? '');
    _addressController =
        TextEditingController(text: widget.userData['direccion'] ?? '');
    _photoUrlController = TextEditingController(
        text: widget.userData['photoURL'] ?? widget.userData['foto_url'] ?? '');
    _dobController =
        TextEditingController(text: widget.userData['fecha_nacimiento'] ?? '');
    _selectedGender = widget.userData['genero'];
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
      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');

      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(resp.body);

        final nombre = (data['nombre_completo'] ?? '').toString();
        final tel = (data['telefono'] ?? '').toString();
        final dir = (data['direccion'] ?? '').toString();
        final foto = (data['foto_url'] ?? '').toString();
        final dob = (data['fecha_nacimiento'] ?? '').toString();
        final genero = (data['genero'] ?? '').toString();

        if (nombre.isNotEmpty) _nameController.text = nombre;
        if (tel.isNotEmpty) _phoneController.text = tel;
        if (dir.isNotEmpty) _addressController.text = dir;
        if (foto.isNotEmpty) _photoUrlController.text = foto;
        if (dob.isNotEmpty) _dobController.text = dob;

        if (genero.isNotEmpty) {
          const opciones = [
            'Masculino',
            'Femenino',
            'Otro',
            'Prefiero no decirlo'
          ];
          _selectedGender = opciones.contains(genero) ? genero : null;
        }

        if (mounted) setState(() {});
      }
    } catch (_) {
      // Silencioso
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  // --- Subir imagen a Cloudinary ---
  Future<void> _pickAndUploadImage() async {
    final XFile? selectedImage =
        await _picker.pickImage(source: ImageSource.gallery);
    if (selectedImage == null) return;

    setState(() => _isUploading = true);

    final cloudinary = CloudinaryPublic('dskg1hw9n', 'Imagenes_Beauteek',
        cache: false);
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(selectedImage.path,
            resourceType: CloudinaryResourceType.Image),
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

      profileData
          .removeWhere((k, v) => v == null || (v is String && v.isEmpty));

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
        final errorMessage =
            (errorData is Map && errorData['message'] != null)
                ? errorData['message'].toString()
                : 'Error al actualizar el perfil.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- UI ----------

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: _textSecondary,
        fontSize: 14,
      ),
      filled: true,
      fillColor: _fieldColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryOrange, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: const Text(
          'Editar Perfil',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
            children: [
              if (_isFetching)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    color: _primaryOrange,
                    backgroundColor: Colors.transparent,
                  ),
                ),

              // Avatar + Cambiar foto
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 64,
                          backgroundColor: Colors.white10,
                          backgroundImage: _imageFile != null
                              ? FileImage(File(_imageFile!.path))
                              : (_photoUrlController.text.isNotEmpty
                                      ? NetworkImage(
                                          _photoUrlController.text)
                                      : null)
                                  as ImageProvider<Object>?,
                          child: _imageFile == null &&
                                  _photoUrlController.text.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: _textSecondary,
                                )
                              : null,
                        ),
                        if (_isUploading)
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(
                                color: _primaryOrange,
                              ),
                            ),
                          ),
                        if (!_isUploading)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: _primaryOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: const Text(
                        'Cambiar foto',
                        style: TextStyle(
                          color: _primaryOrange,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Nombre
              const Text(
                'Nombre',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: _textPrimary),
                decoration: _fieldDecoration('Nombre'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Por favor, ingresa tu nombre'
                        : null,
              ),
              const SizedBox(height: 18),

              // Teléfono
              const Text(
                'Teléfono',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: _textPrimary),
                decoration: _fieldDecoration('Teléfono'),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Por favor, ingresa tu teléfono'
                        : null,
              ),
              const SizedBox(height: 18),

              // Dirección
              const Text(
                'Dirección',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                style: const TextStyle(color: _textPrimary),
                decoration: _fieldDecoration('Dirección'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Por favor, ingresa tu dirección'
                        : null,
              ),
              const SizedBox(height: 18),

              // Fecha de nacimiento
              const Text(
                'Fecha de nacimiento',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _dobController,
                style: const TextStyle(color: _textPrimary),
                decoration: _fieldDecoration('Fecha de nacimiento')
                    .copyWith(
                      suffixIcon: const Icon(Icons.calendar_today,
                          color: _textSecondary),
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
                      _dobController.text =
                          pickedDate.toIso8601String().substring(0, 10);
                    });
                  }
                },
              ),
              const SizedBox(height: 18),

              // Género
              const Text(
                'Género',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                dropdownColor: _fieldColor,
                iconEnabledColor: _textSecondary,
                style: const TextStyle(color: _textPrimary, fontSize: 14),
                decoration: _fieldDecoration('Género'),
                items: const [
                  DropdownMenuItem(
                      value: 'Masculino', child: Text('Masculino')),
                  DropdownMenuItem(
                      value: 'Femenino', child: Text('Femenino')),
                  DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                  DropdownMenuItem(
                      value: 'Prefiero no decirlo',
                      child: Text('Prefiero no decirlo')),
                ],
                onChanged: (value) =>
                    setState(() => _selectedGender = value),
              ),

              const SizedBox(height: 32),

              // Botón Guardar Cambios
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryOrange.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryOrange,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Guardar Cambios',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}