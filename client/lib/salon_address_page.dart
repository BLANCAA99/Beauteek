import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'search_page.dart';
import 'salon_bank_account_page.dart';
import 'package:geocoding/geocoding.dart' as geo;

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
  // 🎨 Tema Beauteek
  static const Color _backgroundColor = Color(0xFF18100A);
  static const Color _fieldColor = Color(0xFF22242C);
  static const Color _primaryOrange = Color(0xFFEA963A);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB7B9C0);

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
    // ✅ CAMBIO: Obtener el userId del usuario actual
    final currentUser = FirebaseAuth.instance.currentUser;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(
          mode: 'select',
          userId: currentUser?.uid, // ✅ AGREGAR userId
          userCountry: 'Honduras', // ✅ AGREGAR país por defecto
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
        'ubicacion': {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        },
        'telefono_sucursal': _telefonoSucursalController.text.trim().isNotEmpty
            ? _telefonoSucursalController.text.trim()
            : null,
      };

      print('📤 Enviando dirección: ${json.encode(payload)}');

      final url = Uri.parse('$apiBaseUrl/comercios/register-salon-step2');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 30));

      print('📥 Status: ${response.statusCode}');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 200) {
        if (!mounted) return;

        // Guardar ubicación en colección ubicaciones
        try {
          // Obtener información de país y ciudad mediante geocodificación inversa
          String pais = 'No especificado';
          String ciudad = 'No especificado';
          
          try {
            List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
              _selectedLocation!.latitude,
              _selectedLocation!.longitude,
            );
            if (placemarks.isNotEmpty) {
              pais = placemarks.first.country ?? 'No especificado';
              ciudad = placemarks.first.locality ?? 
                       placemarks.first.administrativeArea ?? 
                       'No especificado';
            }
          } catch (geoError) {
            print('⚠️ Error en geocodificación: $geoError');
          }

          final ubicacionUrl = Uri.parse('$apiBaseUrl/api/ubicaciones');
          final ubicacionResponse = await http.post(
            ubicacionUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode({
              'uid_usuario': widget.uidNegocio,
              'tipo_entidad': 'salon',
              'es_principal': true,
              'pais': pais,
              'ciudad': ciudad,
              'lat': _selectedLocation!.latitude,
              'lng': _selectedLocation!.longitude,
              'alias': 'Sucursal principal',
              'direccion_completa': _addressController.text.trim(),
            }),
          ).timeout(const Duration(seconds: 30));
          
          if (ubicacionResponse.statusCode == 201) {
            print('✅ Ubicación guardada en colección ubicaciones');
          }
        } catch (ubicacionError) {
          print('❌ Error guardando ubicación: $ubicacionError');
          // No bloquear el flujo si falla, solo registrar
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Sucursal principal creada! Ahora registra tu cuenta bancaria.'),
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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: _textPrimary),
        title: const Text(
          'Ubicación',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const SizedBox(height: 16),
            // Icono grande
            const Center(
              child: Icon(
                Icons.location_on,
                size: 80,
                color: _primaryOrange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ubicación de tu sucursal principal',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Podrás agregar más sucursales después',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            _buildTextField(
              controller: _addressController,
              label: 'Dirección completa *',
              hint: 'Ej: Col. Palmira, Av. República de Chile',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 18),

            _buildTextField(
              controller: _telefonoSucursalController,
              label: 'Teléfono de esta sucursal (opcional)',
              hint: 'Si es diferente al teléfono principal',
              icon: Icons.phone_in_talk_outlined,
              keyboardType: TextInputType.phone,
              isRequired: false,
            ),
            const SizedBox(height: 28),

            // Botón para seleccionar ubicación
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openLocationPicker,
                icon: Icon(
                  _selectedLocation != null ? Icons.check_circle : Icons.map,
                  color: _selectedLocation != null
                      ? Colors.greenAccent
                      : _primaryOrange,
                ),
                label: Text(
                  _selectedLocation != null
                      ? 'Ubicación seleccionada'
                      : 'Seleccionar en el mapa',
                  style: TextStyle(
                    color: _selectedLocation != null
                        ? Colors.greenAccent
                        : _primaryOrange,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: _selectedLocation != null
                        ? Colors.greenAccent
                        : _primaryOrange,
                    width: 1.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),

            if (_selectedLocation != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF123321),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place, color: Colors.greenAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(5)} · '
                        'Lng: ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 34),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 5,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Text(
                        'Siguiente: Cuenta Bancaria',
                        style: TextStyle(
                          fontSize: 16,
                          color: _textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 TextField con estilo oscuro
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
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: _textPrimary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: _textSecondary, fontSize: 14),
            prefixIcon:
                icon != null ? Icon(icon, color: _textSecondary) : null,
            filled: true,
            fillColor: _fieldColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) => isRequired && (value == null || value.isEmpty)
              ? 'Este campo es requerido'
              : null,
        ),
      ],
    );
  }
}