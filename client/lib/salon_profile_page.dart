import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'calendar_page.dart';

class SalonProfilePage extends StatefulWidget {
  final String comercioId;
  
  const SalonProfilePage({
    Key? key,
    required this.comercioId,
  }) : super(key: key);

  @override
  State<SalonProfilePage> createState() => _SalonProfilePageState();
}

class _SalonProfilePageState extends State<SalonProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _comercioData;
  List<Map<String, dynamic>> _servicios = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosComercio();
  }

  Future<void> _cargarDatosComercio() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      
      // ✅ Obtener comercio
      final comercioUrl = Uri.parse('$apiBaseUrl/comercios/${widget.comercioId}');
      
      print('🔍 Cargando comercio: $comercioUrl');
      
      final comercioResponse = await http.get(
        comercioUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (comercioResponse.statusCode == 200) {
        final comercioData = json.decode(comercioResponse.body);
        
        // ✅ CAMBIO: Usar /api/servicios con query param comercio_id
        final serviciosUrl = Uri.parse('$apiBaseUrl/api/servicios?comercio_id=${widget.comercioId}');
        
        print('🔍 Cargando servicios: $serviciosUrl');
        
        final serviciosResponse = await http.get(
          serviciosUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );

        print('📥 Servicios status: ${serviciosResponse.statusCode}');
        print('📥 Servicios body: ${serviciosResponse.body}');

        List<Map<String, dynamic>> servicios = [];
        if (serviciosResponse.statusCode == 200) {
          final List<dynamic> serviciosData = json.decode(serviciosResponse.body);
          servicios = serviciosData
              .map((s) => s as Map<String, dynamic>)
              .toList();
        }

        setState(() {
          _comercioData = comercioData;
          _servicios = servicios;
          _isLoading = false;
        });
        
        print('✅ Comercio cargado: ${comercioData['nombre']}');
        print('✅ Servicios cargados: ${servicios.length}');
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFEA963A)),
        ),
      );
    }

    if (_comercioData == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Error')),
        body: Center(child: Text('No se pudo cargar el salón')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfo(),
                _buildServicios(),
                SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBookButton(),
    );
  }

  Widget _buildAppBar() {
    final fotoUrl = _comercioData!['foto_url'] as String?;
    
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: fotoUrl != null && fotoUrl.isNotEmpty
            ? Image.network(fotoUrl, fit: BoxFit.cover)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEA963A), Color(0xFFFF6B9D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(Icons.store, size: 80, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _comercioData!['nombre'] ?? 'Salón',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.star, color: Color(0xFFFFB800), size: 20),
              SizedBox(width: 4),
              Text(
                '${_comercioData!['calificacion'] ?? 4.5}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _comercioData!['direccion'] ?? 'Dirección no disponible',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicios() {
    if (_servicios.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(20),
        child: Text('No hay servicios disponibles'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Servicios',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 12),
        ..._servicios.map((servicio) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        servicio['nombre'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${servicio['duracion_min']} min',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Text(
                  'L${servicio['precio']?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEA963A),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildBookButton() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CalendarPage(
                mode: 'booking',
                comercioId: widget.comercioId,
                salonName: _comercioData!['nombre'],
                servicios: _servicios,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFEA963A),
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Agendar cita',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
