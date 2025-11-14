import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';

class EstadisticasSalonPage extends StatefulWidget {
  const EstadisticasSalonPage({Key? key}) : super(key: key);

  @override
  State<EstadisticasSalonPage> createState() => _EstadisticasSalonPageState();
}

class _EstadisticasSalonPageState extends State<EstadisticasSalonPage> {
  bool _isLoading = true;
  int _citasHoy = 0;
  double _ingresosHoy = 0;
  int _citasProximos7Dias = 0;
  double _ingresosProximos7Dias = 0;
  List<Map<String, dynamic>> _proximosClientes = [];

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      
      // ✅ CAMBIO: Primero obtener el comercio_id del usuario salon
      print('🔍 Buscando comercio para uid: ${user.uid}');
      
      final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
      final comerciosResponse = await http.get(
        comerciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (comerciosResponse.statusCode != 200) {
        print('❌ Error obteniendo comercios: ${comerciosResponse.statusCode}');
        setState(() => _isLoading = false);
        return;
      }

      final List<dynamic> comercios = json.decode(comerciosResponse.body);
      
      // Buscar el comercio que pertenece a este usuario
      final miComercio = comercios.firstWhere(
        (c) => c['uid_negocio'] == user.uid,
        orElse: () => null,
      );

      if (miComercio == null) {
        print('⚠️ No se encontró comercio para este usuario');
        setState(() => _isLoading = false);
        return;
      }

      final comercioId = miComercio['id'];
      print('✅ Comercio encontrado: $comercioId');

      // ✅ CAMBIO: Obtener todas las citas del comercio (sin filtro de estado)
      final citasUrl = Uri.parse('$apiBaseUrl/citas?comercio_id=$comercioId');
      print('📍 Consultando citas: $citasUrl');
      
      final citasResponse = await http.get(
        citasUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      print('📥 Status citas: ${citasResponse.statusCode}');

      if (citasResponse.statusCode == 200) {
        final List<dynamic> todasLasCitas = json.decode(citasResponse.body);
        print('📋 Total citas encontradas: ${todasLasCitas.length}');
        
        if (todasLasCitas.isNotEmpty) {
          print('📄 Ejemplo de cita: ${todasLasCitas[0]}');
        }
        
        final ahora = DateTime.now();
        final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day);
        final hoyFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
        final fecha7Dias = hoyInicio.add(const Duration(days: 7));

        int citasHoy = 0;
        double ingresosHoy = 0;
        int citas7Dias = 0;
        double ingresos7Dias = 0;
        List<Map<String, dynamic>> proximosList = [];
        final manana = hoyInicio.add(const Duration(days: 1));

        for (var cita in todasLasCitas) {
          try {
            // ✅ CAMBIO: Parsear fecha correctamente
            DateTime fechaCita;
            final fechaHoraStr = cita['fecha_hora'];
            
            if (fechaHoraStr is String) {
              // Si es string tipo "2024-11-14T10:00" o "2024-11-14T10:00:00"
              fechaCita = DateTime.parse(fechaHoraStr);
            } else if (fechaHoraStr is Map && fechaHoraStr.containsKey('_seconds')) {
              // Si es un Timestamp de Firestore serializado
              final seconds = fechaHoraStr['_seconds'] as int;
              fechaCita = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            } else {
              print('⚠️ Formato de fecha no reconocido: $fechaHoraStr');
              continue;
            }

            print('📅 Cita: ${cita['id']} - Fecha: $fechaCita');

            // ✅ Citas de hoy
            if (fechaCita.isAfter(hoyInicio) && fechaCita.isBefore(hoyFin)) {
              citasHoy++;
              ingresosHoy += (cita['precio'] ?? 0).toDouble();
              print('   ✅ Es de hoy');
            }
            // ✅ Citas próximos 7 días (desde mañana)
            if (fechaCita.isAfter(manana) && fechaCita.isBefore(fecha7Dias)) {
              citas7Dias++;
              ingresos7Dias += (cita['precio'] ?? 0).toDouble();
              print('   ✅ Está en próximos 7 días');
            }

            // ✅ Citas futuras para lista de próximos clientes
            if (fechaCita.isAfter(ahora)) {
              proximosList.add({
                ...cita,
                'fecha_hora_parsed': fechaCita,
              });
            }
          } catch (e) {
            print('❌ Error procesando cita ${cita['id']}: $e');
          }
        }

        // Ordenar próximos clientes por fecha
        proximosList.sort((a, b) {
          final fechaA = a['fecha_hora_parsed'] as DateTime;
          final fechaB = b['fecha_hora_parsed'] as DateTime;
          return fechaA.compareTo(fechaB);
        });

        setState(() {
          _citasHoy = citasHoy;
          _ingresosHoy = ingresosHoy;
          _citasProximos7Dias = citas7Dias;
          _ingresosProximos7Dias = ingresos7Dias;
          _proximosClientes = proximosList.take(3).map((c) => c as Map<String, dynamic>).toList();
          _isLoading = false;
        });

        print('✅ Estadísticas calculadas:');
        print('   📅 Hoy ($hoyInicio - $hoyFin):');
        print('      Citas: $citasHoy');
        print('      Ingresos: L${ingresosHoy.toStringAsFixed(2)}');
        print('   📅 Próximos 7 días ($manana - $fecha7Dias):');
        print('      Citas: $citas7Dias');
        print('      Ingresos: L${ingresos7Dias.toStringAsFixed(2)}');
      } else {
        print('Error HTTP: ${citasResponse.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      print('Error cargando estadísticas: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF111418)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Estadísticas',
          style: TextStyle(
            color: Color(0xFF111418),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFEA963A)))
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sección: Hoy
                  Text(
                    'Hoy',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111418),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Cards de Hoy
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Citas',
                          value: '$_citasHoy',
                          color: Color(0xFFF0F0F5),
                          textColor: Color(0xFF111418),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Ingresos',
                          value: 'L${_ingresosHoy.toStringAsFixed(0)}',
                          color: Color(0xFFF0F0F5),
                          textColor: Color(0xFF111418),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Sección: Próximos 7 días
                  Text(
                    'Próximos 7 días',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111418),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Citas próximos 7 días
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(0xFFE8E8E8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Citas',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF637588),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '$_citasProximos7Dias',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111418),
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '7 días ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF637588),
                              ),
                            ),
                            Text(
                              '+${(_citasProximos7Dias * 10).toInt()}%',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Ingresos próximos 7 días
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(0xFFE8E8E8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ingresos',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF637588),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'L${_ingresosProximos7Dias.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111418),
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '7 días ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF637588),
                              ),
                            ),
                            Text(
                              '+5%',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF637588),
            ),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
