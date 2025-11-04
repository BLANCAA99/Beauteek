import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'search_page.dart';
import 'salon_bank_account_page.dart';

class SalonAddressPage extends StatefulWidget {
  final String comercioId;
  final String uidNegocio;

  const SalonAddressPage({
    Key? key,
    required this.comercioId,
    required this.uidNegocio,
  }) : super(key: key);

  @override
  State<SalonAddressPage> createState() => _SalonAddressPageState();
}

class _SalonAddressPageState extends State<SalonAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _telefonoSucursalController = TextEditingController();
  LatLng? _selectedLocation;
  bool _isLoading = false;

  @override
  void dispose() {
    _addressController.dispose();
    _telefonoSucursalController.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(
          mode: 'select',
          onLocationSelected: (position, address) {
            setState(() {
              _selectedLocation = position;
              if (_addressController.text.isEmpty) {
                _addressController.text = address;
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Selecciona la ubicación en el mapa')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Sesión expirada');

      final idToken = await currentUser.getIdToken();

      final payload = {
        'comercioId': widget.comercioId,
        'direccion': _addressController.text.trim(),
        'geo': {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        },
        'telefono_sucursal': _telefonoSucursalController.text.trim().isNotEmpty
            ? _telefonoSucursalController.text.trim()
            : null,
      };

      print('📤 Enviando dirección: ${json.encode(payload)}');

      final url = Uri.parse('$apiBaseUrl/comercios/register-salon-step2');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      print('📥 Status: ${response.statusCode}');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sucursal principal creada! Ahora registra tu cuenta bancaria.'),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SalonBankAccountPage(
              comercioId: widget.comercioId,
              uidNegocio: widget.uidNegocio,
            ),
          ),
        );
      } else {
        String msg = 'Error al guardar dirección';
        try {
          final data = json.decode(response.body);
          msg = data['message'] ?? data['error'] ?? msg;
        } catch (e) {
          print('Error parseando respuesta: $e');
        }
        throw Exception(msg);
      }
    } catch (e) {
      print('❌ Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Ubicación',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Ubicación de tu sucursal principal',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Podrás agregar más sucursales después',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            _buildTextField(
              controller: _addressController,
              label: 'Dirección completa *',
              hint: 'Ej: Col. Palmira, Av. República de Chile',
              icon: Icons.location_on,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _telefonoSucursalController,
              label: 'Teléfono de esta sucursal (opcional)',
              hint: 'Si es diferente al teléfono principal',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              isRequired: false,
            ),
            const SizedBox(height: 24),

            // Botón para seleccionar ubicación
            OutlinedButton.icon(
              onPressed: _openLocationPicker,
              icon: Icon(
                _selectedLocation != null ? Icons.check_circle : Icons.map,
                color: _selectedLocation != null
                    ? Colors.green
                    : const Color(0xFFEA963A),
              ),
              label: Text(
                _selectedLocation != null
                    ? '✓ Ubicación seleccionada'
                    : 'Seleccionar en el mapa',
                style: TextStyle(
                  color: _selectedLocation != null
                      ? Colors.green
                      : const Color(0xFFEA963A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: _selectedLocation != null
                      ? Colors.green
                      : const Color(0xFFEA963A),
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (_selectedLocation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(5)}\n'
                        'Lng: ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
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
                      'Siguiente: Cuenta Bancaria',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) =>
              isRequired && (value == null || value.isEmpty)
                  ? 'Este campo es requerido'
                  : null,
        ),
      ],
    );
  }
}
