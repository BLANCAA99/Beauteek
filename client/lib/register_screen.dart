import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(); // <-- AÑADIDO
  String? _selectedGender;
  String errorMsg = '';

    // --- Controlador para animar el toast de éxito ---
  late AnimationController _toastController;
  OverlayEntry? _toastEntry;

  @override
  void initState() { // <-- AÑADIDO
    super.initState();
    _toastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _toastController.dispose();
    _dobController.dispose(); // <-- AÑADIDO
    super.dispose();
  }

  // --- Método para mostrar un toast animado verde ---
  Future<void> _showSuccessToast(String text) async {
    // La inicialización del controller se mueve a initState

    final curved = CurvedAnimation(
      parent: _toastController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _toastEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 40,
        right: 16,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0), // entra desde la derecha
            end: Offset.zero,
          ).animate(curved),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_toastEntry!);
    await _toastController.forward();                     
    await Future.delayed(const Duration(milliseconds: 1200));
    await _toastController.reverse();          
    _toastEntry?.remove();
  }
  // --- Método principal de registro ---
  Future<void> register() async {
    print('[register] Inicio de registro...');
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmController.text.isEmpty ||
        _dobController.text.isEmpty ||
        _selectedGender == null) {
      setState(() {
        errorMsg = 'Todos los campos son requeridos';
      });
      print('[register] Campos vacíos detectados');
      return;
    }
    if (passwordController.text.length < 6) {
      setState(() {
        errorMsg = 'La contraseña debe tener al menos 6 caracteres';
      });
      print('Contraseña demasiado corta');
      return;
    }
    if (passwordController.text != confirmController.text) {
      setState(() {
        errorMsg = 'Las contraseñas no coinciden';
      });
      print('[register] Contraseñas no coinciden');
      return;
    }
    try {
      print('[register] Creando usuario en Firebase Auth...');
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
     
      final user = credential.user;
      if (user == null) {
        setState(() => errorMsg = 'No se pudo obtener el usuario.');
        print('[register] FirebaseAuth devolvió usuario nulo');
        return;
      }

      print('[register] Usuario creado en Auth: ${user.uid}, ${user.email}');

      final url = Uri.parse('$apiBaseUrl/api/users');

      print('[register] Enviando POST al backend: $url');
      final body = {
        'uid': user.uid,
        'nombre_completo': nameController.text.trim(),
        'email': emailController.text.trim(),
        'fecha_nacimiento': _dobController.text.trim(),
        'genero': _selectedGender,
        'telefono': 'pendiente',
        'rol': 'cliente',
        'foto_url': 'https://example.com/no_aplica.jpg',
        'direccion': 'pendiente',
        'geo_lat': 0.0,
        'geo_lng': 0.0,
        'estado': 'pendiente',
      };
      print('📦 [register] Body enviado al backend: $body');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10)); // ✅ CAMBIO: Reducido a 10s

      print('📨 [register] Respuesta del backend: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[register] Usuario guardado correctamente');
        if (!mounted) return; // ✅ CAMBIO: Verificar mounted
        setState(() => errorMsg = '');

        await _showSuccessToast('Registro exitoso');
        if (!mounted) return; // ✅ CAMBIO: Verificar mounted
        
        Navigator.of(context).pop();
      } else {
        print('[register] Error al guardar usuario');
        if (!mounted) return;
        setState(() {
          errorMsg = 'Error al guardar usuario en la base de datos.';
        });
      }
    } on FirebaseAuthException catch (e) {
      print('[register] FirebaseAuthException: ${e.code}');
      if (!mounted) return; // ✅ CAMBIO: Verificar mounted
      setState(() {
        errorMsg = e.message ?? 'No se pudo registrar. Verifica tus datos.';
      });
    } catch (e) {
      print('[register] Excepción: $e');
      if (!mounted) return; // ✅ CAMBIO: Verificar mounted
      setState(() {
        errorMsg = 'Error inesperado. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Crea tu cuenta',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 32),
              const Text('Nombre completo', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Ingresa tu nombre',
                  filled: true,
                  fillColor: const Color(0xFFF3F1EE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: const TextStyle(color: Color(0xFF9B8C7B)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Correo electrónico', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: 'Ingresa tu correo',
                  filled: true,
                  fillColor: const Color(0xFFF3F1EE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: const TextStyle(color: Color(0xFF9B8C7B)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Contraseña', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Ingresa tu contraseña',
                  filled: true,
                  fillColor: const Color(0xFFF3F1EE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: const TextStyle(color: Color(0xFF9B8C7B)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Confirmar contraseña', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirma tu contraseña',
                  filled: true,
                  fillColor: const Color(0xFFF3F1EE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: const TextStyle(color: Color(0xFF9B8C7B)),
                ),
              ),
              const SizedBox(height: 16),
              // --- Campo Fecha de Nacimiento ---
              TextFormField(
                controller: _dobController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Fecha de Nacimiento',
                  filled: true,
                  fillColor: const Color(0xFFF3F1EE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Sugerir 18 años
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
              // --- Campo Género ---
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  labelText: 'Género',
                  filled: true,
                  fillColor: const Color(0xFFF3F1EE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                hint: const Text('Selecciona tu género'),
                items: ['Masculino', 'Femenino', 'Otro', 'Prefiero no decirlo']
                    .map((label) => DropdownMenuItem(
                          child: Text(label),
                          value: label,
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    errorMsg,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA963A),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: register,
                  child: const Text(
                    'Registrarse',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    const Text(
                      '¿Ya tienes una cuenta?',
                      style: TextStyle(color: Color(0xFF9B8C7B)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Ingresar',
                        style: TextStyle(
                          color: Color(0xFF9B8C7B),
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}