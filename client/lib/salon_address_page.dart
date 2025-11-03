import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'search_page.dart'; // Asegúrate de tener este import
import 'salon_services_schedules_page.dart'; // Agregar este import

class SalonAddressPage extends StatefulWidget {
  final String comercioId;
  final String uidNegocio;

  const SalonAddressPage({
    Key? key,
    required this.comercioId,
    required this.uidNegocio,
  }) : super(key: key);

  @override
  _SalonAddressPageState createState() => _SalonAddressPageState();
}

class _SalonAddressPageState extends State<SalonAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  LatLng? _selectedLocation;
  bool _isLoading = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  // Función para abrir el selector de ubicación
  Future<void> _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(
          mode: 'select',
          onLocationSelected: (position, address) {
            setState(() {
              _selectedLocation = position;
              _addressController.text = address;
            });
          },
        ),
      ),
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una ubicación en el mapa')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Obtener el token de autenticación
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('No hay sesión activa');
      
      final idToken = await currentUser.getIdToken();

      // Llamar al API para actualizar la dirección (paso 2)
      final payload = {
        'comercioId': widget.comercioId,
        'direccion': _addressController.text.trim(),
        'geo': {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        },
      };

      final url = Uri.parse('$apiBaseUrl/comercios/register-salon-step2'); // Sin /api

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('¡Dirección guardada! Ahora configura servicios y horarios.')),
        );

        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;

        // Navegar a la página de servicios y horarios
        navigator.pushReplacement(MaterialPageRoute(
          builder: (context) => SalonServicesSchedulesPage(
            comercioId: widget.comercioId,
            uidNegocio: widget.uidNegocio,
          ),
        ));

      } else {
        String msg = 'Error al guardar la dirección';
        try {
          final data = json.decode(response.body);
          msg = data['message'] ?? data['error'] ?? msg;
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error al guardar dirección: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Paso 2: Dirección del Salón', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          children: [
            const SizedBox(height: 24),
            const Text(
              '¿Dónde se encuentra tu salón?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Selecciona la ubicación exacta para que tus clientes puedan encontrarte fácilmente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ej: Col. Palmira, Calle Principal, Casa #123',
                prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'La dirección es requerida' : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openLocationPicker,
              icon: Icon(
                _selectedLocation == null ? Icons.map : Icons.edit_location,
                color: const Color(0xFFF5B1A8),
              ),
              label: Text(
                _selectedLocation == null
                    ? 'Seleccionar ubicación en el mapa'
                    : 'Cambiar ubicación en el mapa',
                style: const TextStyle(color: Color(0xFFF5B1A8)),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFF5B1A8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedLocation != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ubicación seleccionada\nLat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5B1A8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Siguiente: Servicios y Horarios',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
