import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'package:flutter/src/widgets/basic.dart' as basic;
import 'payment_screen.dart';
import 'review_screen.dart';
import 'package:intl/intl.dart'; // <-- AGREGAR ESTA IMPORTACIÓN
import 'package:intl/date_symbol_data_local.dart'; // <-- AGREGAR ESTA IMPORTACIÓN

class CalendarPage extends StatefulWidget {
  final String mode;
  final String? comercioId; // ✅ CAMBIO: Renombrado de salonId
  final String? salonName;
  final List<Map<String, dynamic>>? servicios;

  const CalendarPage({
    Key? key,
    this.mode = 'view',
    this.comercioId, // ✅ CAMBIO
    this.salonName,
    this.servicios,
  }) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  String? _userRole;
  String? _userId;
  bool _isLoading = true;
  
  // Para modo booking
  String? _selectedServicioId;
  TimeOfDay? _selectedTime;
  List<String> _horasDisponibles = [];
  
  // Citas reales desde Firestore
  List<Map<String, dynamic>> _citas = []; // <-- CAMBIO: ahora se cargan de Firestore

  @override
  void initState() {
    super.initState();
    _initializeLocale(); // <-- CAMBIO: inicializar locale primero
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('es_ES', null); // <-- ARREGLA EL ERROR DE LOCALE
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      _userId = user.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      setState(() {
        _userRole = userDoc.data()?['rol'] as String? ?? 'cliente';
      });

      if (widget.mode == 'booking') {
        _generarHorasDisponibles();
      }

      // Cargar citas reales
      await _cargarCitasReales();
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error cargando datos del usuario: $e');
      setState(() {
        _userRole = 'cliente';
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarCitasReales() async {
    if (_userId == null) return;

    try {
      print('🔍 Buscando citas para usuario: $_userId (rol: $_userRole)');

      Query query = FirebaseFirestore.instance.collection('citas');

      // ✅ CAMBIO: Solo filtrar por usuario_cliente_id o por comercio_id
      if (_userRole == 'cliente') {
        query = query.where('usuario_cliente_id', isEqualTo: _userId);
      } else if (_userRole == 'salon') {
        // Para salones, buscar por comercio donde uid_negocio == _userId
        final comerciosSnapshot = await FirebaseFirestore.instance
            .collection('comercios')
            .where('uid_negocio', isEqualTo: _userId)
            .get();
        
        if (comerciosSnapshot.docs.isEmpty) {
          print('ℹ️ No hay comercios para este salón');
          setState(() {
            _citas = [];
          });
          return;
        }
        
        final comercioIds = comerciosSnapshot.docs.map((doc) => doc.id).toList();
        print('🏢 Comercios encontrados: $comercioIds');
        
        // Firestore limita 'in' a 10 elementos
        if (comercioIds.length > 10) {
          print('⚠️ Más de 10 comercios, limitando a los primeros 10');
          query = query.where('comercio_id', whereIn: comercioIds.take(10).toList());
        } else {
          query = query.where('comercio_id', whereIn: comercioIds);
        }
      }

      final snapshot = await query.get();

      print('📋 Documentos encontrados: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('ℹ️ No hay citas para este usuario');
        setState(() {
          _citas = [];
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final idToken = user != null ? await user.getIdToken() : null;

      final citasTemp = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        
        print('📄 Procesando cita: ${doc.id}');
        
        // Obtener nombre de la otra persona según el rol
        String nombreOtraPersona = 'Desconocido';
        
        if (_userRole == 'cliente' && data['comercio_id'] != null && idToken != null) {
          try {
            final comercioUrl = Uri.parse('$apiBaseUrl/comercios/${data['comercio_id']}');
            final comercioResponse = await http.get(
              comercioUrl,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
            );
            
            if (comercioResponse.statusCode == 200) {
              final comercioData = json.decode(comercioResponse.body);
              nombreOtraPersona = comercioData['nombre'] ?? 'Salón sin nombre';
            }
          } catch (e) {
            print('⚠️ Error obteniendo comercio: $e');
          }
        } else if (_userRole == 'salon' && data['usuario_cliente_id'] != null && idToken != null) {
          try {
            final clienteUrl = Uri.parse('$apiBaseUrl/api/users/uid/${data['usuario_cliente_id']}');
            final clienteResponse = await http.get(
              clienteUrl,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
            );
            
            if (clienteResponse.statusCode == 200) {
              final clienteData = json.decode(clienteResponse.body);
              nombreOtraPersona = clienteData['nombre_completo'] ?? 'Cliente';
            }
          } catch (e) {
            print('⚠️ Error obteniendo cliente: $e');
          }
        }

        // Parsear fecha_hora
        DateTime fechaHora;
        try {
          if (data['fecha_hora'] is String) {
            String fechaStr = data['fecha_hora'];
            if (fechaStr.length == 16) {
              fechaStr += ':00';
            }
            fechaHora = DateTime.parse(fechaStr);
          } else if (data['fecha_hora'] is Timestamp) {
            fechaHora = (data['fecha_hora'] as Timestamp).toDate();
          } else {
            fechaHora = DateTime.now();
          }
        } catch (e) {
          print('   ❌ Error parseando fecha: $e');
          fechaHora = DateTime.now();
        }

        return {
          'id': doc.id,
          'fecha_hora': fechaHora,
          'nombre_otra_persona': nombreOtraPersona,
          'servicio_nombre': data['servicio_nombre'] ?? 'Servicio',
          'servicio_id': data['servicio_id'],
          'precio': (data['precio'] ?? 0).toDouble(),
          'estado': data['estado'] ?? 'pendiente',
          'duracion_min': data['duracion_min'] ?? 30,
          'comercio_id': data['comercio_id'],
          'cliente_id': data['usuario_cliente_id'],
        };
      }).toList());

      citasTemp.sort((a, b) {
        final fechaA = a['fecha_hora'] as DateTime;
        final fechaB = b['fecha_hora'] as DateTime;
        return fechaA.compareTo(fechaB);
      });

      setState(() {
        _citas = citasTemp;
      });

      print('✅ ${_citas.length} citas cargadas');
    } catch (e) {
      print('❌ Error cargando citas: $e');
      setState(() {
        _citas = [];
      });
    }
  }

  void _generarHorasDisponibles() {
    // Generar horas de 9:00 AM a 6:00 PM cada 30 minutos
    _horasDisponibles = [];
    for (int hora = 9; hora < 18; hora++) {
      _horasDisponibles.add('${hora.toString().padLeft(2, '0')}:00');
      _horasDisponibles.add('${hora.toString().padLeft(2, '0')}:30');
    }
    setState(() {});
  }

  Future<bool> _verificarDisponibilidad(DateTime fecha, String hora) async {
    final fechaHoraCompleta = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      int.parse(hora.split(':')[0]),
      int.parse(hora.split(':')[1]),
    );

    // Buscar en citas reales
    final citaExistente = _citas.any((cita) {
      final citaFecha = cita['fecha_hora'] as DateTime;
      return citaFecha.year == fechaHoraCompleta.year &&
          citaFecha.month == fechaHoraCompleta.month &&
          citaFecha.day == fechaHoraCompleta.day &&
          citaFecha.hour == fechaHoraCompleta.hour &&
          citaFecha.minute == fechaHoraCompleta.minute;
    });

    return !citaExistente;
  }

  Future<void> _confirmarCita() async {
    if (_selectedServicioId == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un servicio y una hora'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final horaStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
    final disponible = await _verificarDisponibilidad(_selectedDate, horaStr);

    if (!disponible) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hora no disponible'),
          content: const Text(
            'Lo sentimos, el salón ya tiene una cita agendada en este horario. Por favor selecciona otra hora o día.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // Mostrar confirmación
    if (!mounted) return;
    final servicio = widget.servicios?.firstWhere(
      (s) => s['id'] == _selectedServicioId,
      orElse: () => {},
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cita'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Servicio: ${servicio?['nombre'] ?? 'N/A'}'),
            Text('Fecha: ${_formatDate(_selectedDate)}'),
            Text('Hora: $horaStr'),
            Text('Precio: L${servicio?['precio']?.toStringAsFixed(2) ?? '0.00'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _guardarCita(servicio);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA963A),
            ),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarCita(Map<String, dynamic>? servicio) async {
    if (servicio == null || _userId == null) return;

    try {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado');

      final idToken = await user.getIdToken();

      final fechaHora = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // ✅ CAMBIO: Simplificado, solo enviar comercio_id y usuario_cliente_id
      final payload = {
        'comercio_id': widget.comercioId,
        'servicio_id': servicio['id'],
        'usuario_cliente_id': _userId,
        'fecha_hora': fechaHora.toIso8601String().substring(0, 16),
        'duracion_min': servicio['duracion_min'],
        'precio': servicio['precio'],
        'servicio_nombre': servicio['nombre'],
        'estado': 'pendiente',
      };

      print('📤 Enviando cita: ${json.encode(payload)}');

      final url = Uri.parse('$apiBaseUrl/citas');
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

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        
        String? citaId;
        
        if (responseData.containsKey('citaId')) {
          citaId = responseData['citaId']?.toString();
        } else if (responseData.containsKey('id')) {
          citaId = responseData['id']?.toString();
        } else if (responseData.containsKey('cita_id')) {
          citaId = responseData['cita_id']?.toString();
        } else if (responseData is Map && responseData.containsKey('cita')) {
          citaId = responseData['cita']?['id']?.toString();
        }
        
        print('🆔 Cita ID extraído: $citaId');
        
        if (citaId == null || citaId.isEmpty) {
          print('⚠️ Estructura de respuesta: ${responseData.keys.toList()}');
          throw Exception('No se pudo obtener el ID de la cita de la respuesta');
        }

        // ✅ Capturar todas las variables necesarias ANTES del diálogo
        final citaIdFinal = citaId;
        final montoFinal = (servicio['precio'] as num?)?.toDouble() ?? 0.0;
        final salonNameFinal = widget.salonName ?? 'Salón de belleza';
        
        print('💰 Datos para pago: citaId=$citaIdFinal, monto=$montoFinal, salon=$salonNameFinal');
        
        await _cargarCitasReales();
        setState(() => _isLoading = false);

        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('¡Cita agendada!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tu cita ha sido agendada exitosamente.'),
                const SizedBox(height: 16),
                const Text(
                  '¿Cómo deseas pagar?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Valor del servicio: L${montoFinal.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Pagar en el local'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // ✅ Agregar try-catch para capturar el error exacto
                  try {
                    print('🚀 Navegando a PaymentScreen con: citaId=$citaIdFinal, monto=$montoFinal, salon=$salonNameFinal');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(
                          citaId: citaIdFinal,
                          monto: montoFinal,
                          salonName: salonNameFinal,
                        ),
                      ),
                    ).then((pagado) {
                      if (pagado == true) {
                        Navigator.pop(context);
                      }
                    });
                  } catch (e, stackTrace) {
                    print('❌ Error al navegar a PaymentScreen: $e');
                    print('Stack: $stackTrace');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al abrir pantalla de pago: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA963A),
                ),
                child: const Text(
                  'Pagar en la app',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      } else if (response.statusCode == 409) {
        setState(() => _isLoading = false);
        
        final data = json.decode(response.body);
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Horario no disponible'),
            content: Text(data['mensaje'] ?? 'Este horario ya está ocupado'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error guardando cita: $e');
      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al agendar cita: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getCitasDelDia() {
    return _citas.where((cita) {
      final fechaCita = cita['fecha_hora'] as DateTime;
      return _isSameDay(fechaCita, _selectedDate);
    }).toList();
  }

  int _getCitasCount(DateTime date) {
    return _citas.where((cita) {
      final fechaCita = cita['fecha_hora'] as DateTime;
      return _isSameDay(fechaCita, date);
    }).length;
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null; // Reset hora seleccionada
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2B7FDB)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.mode == 'booking' ? 'Agendar Cita' : (_userRole == 'salon' ? 'Mis Clientes Agendados' : 'Mis Citas'),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildCalendar(),
          const SizedBox(height: 24),
          Expanded(
            child: widget.mode == 'booking'
                ? _buildBookingForm()
                : _buildCitasList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fecha seleccionada
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2B7FDB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF2B7FDB)),
                const SizedBox(width: 12),
                Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Seleccionar servicio
          const Text(
            'Selecciona un servicio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.servicios == null || widget.servicios!.isEmpty)
            Text(
              'No hay servicios disponibles',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ...widget.servicios!.map((servicio) {
              final isSelected = _selectedServicioId == servicio['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedServicioId = servicio['id'];
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFEA963A).withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFEA963A)
                          : Colors.grey.shade200,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFFEA963A),
                          size: 24,
                        ),
                      if (isSelected) const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              servicio['nombre'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${servicio['duracion_min']} min • L${servicio['precio']?.toStringAsFixed(2) ?? '0.00'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

          const SizedBox(height: 24),

          // Seleccionar hora
          const Text(
            'Selecciona una hora',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _horasDisponibles.map((hora) {
              final horaTime = TimeOfDay(
                hour: int.parse(hora.split(':')[0]),
                minute: int.parse(hora.split(':')[1]),
              );
              final isSelected = _selectedTime?.hour == horaTime.hour &&
                  _selectedTime?.minute == horaTime.minute;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTime = horaTime;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2B7FDB)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2B7FDB)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    hora,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmarCita,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA963A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirmar cita',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Navegación de mes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                _formatMonth(_currentMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Días de la semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['D', 'L', 'M', 'M', 'J', 'V', 'S']
                .map((day) => SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          _buildDaysGrid(),
        ],
      ),
    );
  }

  Widget _buildDaysGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startingWeekday = firstDayOfMonth.weekday % 7;
    
    // ✅ CAMBIO: Normalizar fecha actual (sin hora) para comparaciones
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: daysInMonth + startingWeekday,
      itemBuilder: (context, index) {
        if (index < startingWeekday) {
          return const SizedBox();
        }

        final day = index - startingWeekday + 1;
        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
        final isSelected = _isSameDay(date, _selectedDate);
        final isToday = _isSameDay(date, DateTime.now());
        // ✅ CAMBIO: Un día es pasado solo si es ANTES de hoy (no incluye hoy)
        final isPast = date.isBefore(today);
        final citasCount = _getCitasCount(date);
        final hasCitas = citasCount > 0;
        
        // ✅ CAMBIO: Solo bloquear días pasados en modo booking
        final isDisabled = widget.mode == 'booking' && isPast;

        return InkWell(
          onTap: isDisabled ? null : () => _selectDate(date),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2B7FDB)
                  : (isToday ? const Color(0xFF2B7FDB).withOpacity(0.1) : Colors.transparent),
              shape: BoxShape.circle,
              border: hasCitas && !isSelected && widget.mode == 'view'
                  ? Border.all(color: const Color(0xFF2B7FDB), width: 2)
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: (widget.mode == 'booking' && isPast) 
                          ? Colors.grey.shade400 
                          : (isSelected ? Colors.white : Colors.black),
                      fontWeight: hasCitas ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (hasCitas && !isSelected && widget.mode == 'view')
                  Positioned(
                    bottom: 4,
                    right: 0,
                    left: 0,
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2B7FDB),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCitasList() {
    final citasDelDia = _getCitasDelDia();

    if (citasDelDia.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay citas para este día',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(_selectedDate),
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: citasDelDia.length,
      itemBuilder: (context, index) {
        final cita = citasDelDia[index];
        final fechaHora = cita['fecha_hora'] as DateTime;
        final hora = DateFormat('HH:mm').format(fechaHora);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF2B7FDB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hora.split(':')[0],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B7FDB),
                    ),
                  ),
                  Text(
                    hora.split(':')[1],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2B7FDB),
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              cita['nombre_otra_persona'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  cita['servicio_nombre'] ?? 'Servicio',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'L${cita['precio']?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
            onTap: () => _showCitaDetails(cita),
          ),
        );
      },
    );
  }

  void _showCitaDetails(Map<String, dynamic> cita) {
    final fechaHora = cita['fecha_hora'] as DateTime;
    final isPast = fechaHora.isBefore(DateTime.now());
    final canReview = isPast && _userRole == 'cliente' && cita['estado'] == 'finalizada';
    final canFinalize = _userRole == 'salon' && cita['estado'] != 'finalizada' && cita['estado'] != 'cancelada';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detalles de la cita',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
              Icons.calendar_today,
              'Fecha',
              _formatDateLong(fechaHora),
            ),
            _buildDetailRow(
              Icons.access_time,
              'Hora',
              DateFormat('HH:mm').format(fechaHora),
            ),
            _buildDetailRow(
              _userRole == 'cliente' ? Icons.store : Icons.person,
              _userRole == 'cliente' ? 'Salón' : 'Cliente',
              cita['nombre_otra_persona'],
            ),
            _buildDetailRow(
              Icons.design_services,
              'Servicio',
              cita['servicio_nombre'] ?? 'N/A',
            ),
            _buildDetailRow(
              Icons.attach_money,
              'Precio',
              'L${cita['precio']?.toStringAsFixed(2) ?? '0.00'}',
            ),
            _buildDetailRow(
              Icons.info_outline,
              'Estado',
              _getStatusText(cita['estado']),
            ),
            const SizedBox(height: 24),
            
            // ✅ CAMBIO: Botón para salón (Finalizar cita)
            if (canFinalize)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _finalizarCita(cita),
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text(
                    'Marcar como Finalizada',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            
            // ✅ CAMBIO: Botón para cliente (Dejar reseña)
            if (canReview)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(
                          citaId: cita['id'],
                          comercioId: cita['comercio_id'], // ✅ CAMBIO: Solo comercioId
                          salonName: cita['nombre_otra_persona'],
                          servicioId: cita['servicio_id'],
                        ),
                      ),
                    ).then((reviewed) {
                      if (reviewed == true) {
                        _cargarCitasReales();
                      }
                    });
                  },
                  icon: const Icon(Icons.rate_review, color: Colors.white),
                  label: const Text(
                    'Dejar reseña',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA963A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: Finalizar cita (solo para salón)
  Future<void> _finalizarCita(Map<String, dynamic> cita) async {
    try {
      Navigator.pop(context); // Cerrar modal
      
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado');

      final idToken = await user.getIdToken();

      final url = Uri.parse('$apiBaseUrl/citas/${cita['id']}');
      
      print('🔄 Actualizando estado de cita: ${cita['id']}');
      
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'estado': 'finalizada',
        }),
      );

      print('📥 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        await _cargarCitasReales();
        
        setState(() => _isLoading = false);

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita marcada como finalizada'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error finalizando cita: $e');
      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2B7FDB), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonth(DateTime date) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    final days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${days[date.weekday % 7]}, ${date.day} de ${months[date.month - 1]}';
  }

  String _formatDateLong(DateTime date) {
    final days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${days[date.weekday % 7]}, ${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    // ✅ CAMBIO: Comparar solo año, mes y día (ignorar hora)
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color _getStatusColor(String? estado) {
    switch (estado) {
      case 'confirmada':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? estado) {
    switch (estado) {
      case 'confirmada':
        return 'Confirmada';
      case 'pendiente':
        return 'Pendiente';
      case 'cancelada':
        return 'Cancelada';
      default:
        return 'Desconocido';
    }
  }
}