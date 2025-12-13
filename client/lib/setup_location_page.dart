import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'search_page.dart';
import 'inicio.dart';
import 'api_constants.dart';

class SetupLocationPage extends StatefulWidget {
  const SetupLocationPage({Key? key}) : super(key: key);

  @override
  State<SetupLocationPage> createState() => _SetupLocationPageState();
}

class _SetupLocationPageState extends State<SetupLocationPage> {
  LatLng? _selectedLocation;
  bool _isLoading = false;

  Future<void> _openLocationPicker() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(
          mode: 'select',
          onLocationSelected: (position, address) {
            setState(() {
              _selectedLocation = position;
            });
          },
        ),
      ),
    );
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Selecciona tu ubicación para continuar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('No hay usuario autenticado');

      // Obtener país y ciudad desde las coordenadas usando geocoding
      String? pais;
      String? ciudad;
      String? direccionCompleta;
      
      try {
        final placemarks = await placemarkFromCoordinates(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          pais = place.country;
          ciudad = place.locality ?? place.administrativeArea;
          direccionCompleta = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'.trim();
          print('🌍 País detectado: $pais, Ciudad: $ciudad');
        }
      } catch (e) {
        print('⚠️ Error obteniendo país: $e');
        pais = 'Honduras'; // Fallback
      }

      if (pais == null || pais.isEmpty) {
        throw Exception('No se pudo detectar el país');
      }

      // Guardar SOLO en colección ubicaciones
      final idToken = await FirebaseAuth.instance.currentUser!.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/ubicaciones');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'uid_usuario': uid,
          'tipo_entidad': 'cliente',
          'pais': pais,
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
          'es_principal': true,
          'ciudad': ciudad,
          'direccion_completa': direccionCompleta,
          'alias': 'Mi ubicación',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 201) {
        throw Exception('Error al guardar ubicación');
      }

      print('✅ Ubicación guardada en colección ubicaciones');

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const InicioPage()),
        (route) => false,
      );
    } catch (e) {
      print('❌ Error guardando ubicación: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Evitar que el usuario pueda salir sin guardar ubicación
      onWillPop: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Debes configurar tu ubicación para continuar'),
            backgroundColor: Colors.orange,
          ),
        );
        return false; // No permite salir
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              // Icono principal
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA963A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 80,
                  color: Color(0xFFEA963A),
                ),
              ),
              const SizedBox(height: 32),

              // Título
              const Text(
                '¿Dónde te encuentras?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111418),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Descripción
              const Text(
                'Necesitamos tu ubicación para mostrarte los salones de belleza más cercanos a ti',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF637588),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Botón para seleccionar ubicación
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
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
                      fontSize: 16,
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
              ),

              // Mostrar coordenadas si ya seleccionó
              if (_selectedLocation != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Ubicación confirmada',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Botón continuar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA963A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Botón omitir (opcional, puedes quitarlo si es obligatorio)
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Ubicación requerida'),
                      content: const Text(
                        'Necesitamos tu ubicación para mostrarte los salones cercanos. Sin ella, no podrás usar la aplicación correctamente.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Entendido'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  '¿Por qué necesitas mi ubicación?',
                  style: TextStyle(color: Color(0xFF637588)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
