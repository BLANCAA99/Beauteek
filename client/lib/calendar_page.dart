import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'payment_screen.dart';
import 'review_screen.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';

class CalendarPage extends StatefulWidget {
  final String mode;
  final String? comercioId;
  final String? salonName;
  final List<Map<String, dynamic>>? servicios;
  final String? servicioId;
  final String? promocionId;

  const CalendarPage({
    Key? key,
    this.mode = 'view',
    this.comercioId,
    this.salonName,
    this.servicios,
    this.servicioId,
    this.promocionId,
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

  // Citas reales desde API
  List<Map<String, dynamic>> _citas = [];

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('es_ES', null);
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

      // ✅ Obtener rol del usuario desde la API
      try {
        final idToken = await user.getIdToken();
        final userUrl = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');
        final userResponse = await http.get(
          userUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );

        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          setState(() {
            _userRole = userData['rol'] as String? ?? 'cliente';
          });
        } else {
          setState(() {
            _userRole = 'cliente';
          });
        }
      } catch (e) {
        print('⚠️ Error obteniendo rol del usuario: $e');
        setState(() {
          _userRole = 'cliente';
        });
      }

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

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No hay usuario autenticado');
        setState(() => _citas = []);
        return;
      }

      final idToken = await user.getIdToken();

      final url = Uri.parse('$apiBaseUrl/citas/usuario/${_userId}');
      print('📡 Llamando a API: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 404) {
        print('ℹ️ No hay citas para este usuario');
        setState(() => _citas = []);
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }

      final List<dynamic> citasData = json.decode(response.body);
      print('📋 Citas recibidas: ${citasData.length}');

      final citasTemp = await Future.wait(citasData.map((data) async {
        print('📄 Procesando cita: ${data['id']}');

        String nombreOtraPersona = 'Desconocido';

        final user = FirebaseAuth.instance.currentUser;
        final idToken = await user!.getIdToken();

        if (_userRole == 'cliente' && data['comercio_id'] != null) {
          try {
            final comercioUrl =
                Uri.parse('$apiBaseUrl/comercios/${data['comercio_id']}');
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
        } else if (_userRole == 'salon' && data['usuario_cliente_id'] != null) {
          try {
            final clienteUrl = Uri.parse(
                '$apiBaseUrl/api/users/uid/${data['usuario_cliente_id']}');
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

        DateTime fechaHora;
        try {
          if (data['fecha_hora'] is String) {
            String fechaStr = data['fecha_hora'];
            if (fechaStr.length == 16) {
              fechaStr += ':00';
            }
            fechaHora = DateTime.parse(fechaStr);
          } else if (data['fecha_hora'] is Map &&
              data['fecha_hora']['_seconds'] != null) {
            fechaHora = DateTime.fromMillisecondsSinceEpoch(
              data['fecha_hora']['_seconds'] * 1000,
            );
          } else {
            fechaHora = DateTime.now();
          }
        } catch (e) {
          print('   ❌ Error parseando fecha: $e');
          fechaHora = DateTime.now();
        }

        return {
          'id': data['id'],
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

  // 🔹 DIÁLOGO "CONFIRMAR CITA" CON DISEÑO IGUAL A LA IMAGEN
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

    final horaStr =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
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

    if (!mounted) return;
    final servicio = widget.servicios?.firstWhere(
      (s) => s['id'] == _selectedServicioId,
      orElse: () => {},
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5EE),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Confirmar cita',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Servicio: ${servicio?['nombre'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fecha: ${_formatDate(_selectedDate)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hora: $horaStr',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Precio: L${(servicio?['precio'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5F5F5F),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _guardarCita(servicio);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

      final payload = {
        'comercio_id': widget.comercioId,
        'servicio_id': servicio['id'],
        'usuario_cliente_id': _userId,
        'fecha_hora': fechaHora.toIso8601String().substring(0, 16),
        'duracion_min': servicio['duracion_min'] ?? servicio['duracion'] ?? 60,
        'precio': servicio['precio'],
        'servicio_nombre': servicio['nombre'],
        'estado': 'pendiente',
      };

      print('📤 Enviando cita: ${json.encode(payload)}');

      final url = Uri.parse('$apiBaseUrl/citas');
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
          throw Exception(
              'No se pudo obtener el ID de la cita de la respuesta');
        }

        final citaIdFinal = citaId;
        final montoFinal = (servicio['precio'] as num?)?.toDouble() ?? 0.0;
        final salonNameFinal = widget.salonName ?? 'Salón de belleza';
        final precioOriginal = servicio['precio_original'] as num?;
        final descuento = servicio['descuento'] as num?;

        print(
            '💰 Datos para pago: citaId=$citaIdFinal, monto=$montoFinal, salon=$salonNameFinal, precioOriginal=$precioOriginal, descuento=$descuento');

        await _cargarCitasReales();
        setState(() => _isLoading = false);

        if (!mounted) return;

        // 🔹 DIÁLOGO DE ÉXITO CON MISMO DISEÑO
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5EE),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        '¡Cita agendada!',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tu cita ha sido agendada exitosamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '¿Cómo deseas pagar?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Valor del servicio: L${montoFinal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // cierra diálogo
                            Navigator.pop(context); // vuelve atrás
                          },
                          child: const Text(
                            'Pagar en el local',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5F5F5F),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // cierra diálogo
                            try {
                              print(
                                  '🚀 Navegando a PaymentScreen con: citaId=$citaIdFinal, monto=$montoFinal, salon=$salonNameFinal');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentScreen(
                                    citaId: citaIdFinal,
                                    monto: montoFinal,
                                    salonName: salonNameFinal,
                                    precioOriginal: precioOriginal?.toDouble(),
                                    descuento: descuento?.toDouble(),
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
                                  content: Text(
                                      'Error al abrir pantalla de pago: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOrange,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Pagar en la app',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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
      _selectedTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange),
        ),
      );
    }

    final bgColor = const Color(0xFFF7F3EE);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.mode == 'booking'
              ? 'Agendar Cita'
              : (_userRole == 'salon' ? 'Mis Clientes Agendados' : 'Mis Citas'),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildCalendar(),
          const SizedBox(height: 16),
          Expanded(
            child: widget.mode == 'booking'
                ? _buildBookingForm()
                : _buildCitasList(),
          ),
        ],
      ),
    );
  }

  TextStyle get _sectionTitleStyle => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      );

  Widget _buildBookingForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: AppTheme.primaryOrange, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fecha seleccionada',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C7C7C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Selecciona un servicio', style: _sectionTitleStyle),
          const SizedBox(height: 12),
          if (widget.servicios == null || widget.servicios!.isEmpty)
            Text(
              'No hay servicios disponibles',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.servicios!.map((servicio) {
                final isSelected = _selectedServicioId == servicio['id'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedServicioId = servicio['id'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryOrange.withOpacity(0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryOrange
                            : Colors.grey.shade300,
                        width: 1.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          servicio['nombre'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primaryOrange
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 28),
          Text('Horarios disponibles', style: _sectionTitleStyle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
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
                  width: 100,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryOrange.withOpacity(0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryOrange
                          : Colors.grey.shade300,
                      width: 1.6,
                    ),
                  ),
                  child: Text(
                    hora,
                    style: TextStyle(
                      color:
                          isSelected ? AppTheme.primaryOrange : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
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
              style: AppTheme.primaryButtonStyle().copyWith(
                minimumSize:
                    MaterialStateProperty.all(const Size(double.infinity, 56)),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              child: const Text(
                'Confirmar Cita',
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.black87),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  _formatMonth(_currentMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.black87),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (widget.mode == 'booking') ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Elige una fecha',
                  style: _sectionTitleStyle.copyWith(fontSize: 18),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO']
                  .map(
                    (day) => SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB0B0B0),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            _buildDaysGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysGrid() {
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startingWeekday = firstDayOfMonth.weekday % 7;

    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

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
        final isPast = date.isBefore(today);
        final citasCount = _getCitasCount(date);
        final hasCitas = citasCount > 0;

        final isDisabled = widget.mode == 'booking' && isPast;

        final baseTextColor = isDisabled
            ? Colors.grey.shade300
            : (isSelected ? Colors.white : Colors.black87);

        return InkWell(
          onTap: isDisabled ? null : () => _selectDate(date),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(
                      color: AppTheme.primaryOrange.withOpacity(0.5),
                      width: 1.8,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: baseTextColor,
                      fontWeight: hasCitas ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (hasCitas && !isSelected && widget.mode == 'view')
                  Positioned(
                    bottom: 6,
                    right: 0,
                    left: 0,
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: citasDelDia.length,
      itemBuilder: (context, index) {
        final cita = citasDelDia[index];
        final fechaHora = cita['fecha_hora'] as DateTime;
        final hora = DateFormat('HH:mm').format(fechaHora);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hora.split(':')[0],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  Text(
                    hora.split(':')[1],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.primaryOrange,
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
                color: Colors.black87,
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
                    color: Colors.grey.shade500,
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
    final canReview =
        isPast && _userRole == 'cliente' && cita['estado'] == 'completada';
    final canFinalize = _userRole == 'salon' &&
        cita['estado'] != 'completada' &&
        cita['estado'] != 'cancelada';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
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
                          comercioId: cita['comercio_id'],
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
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            // Botón de cancelar para clientes con citas pendientes
            if (_userRole == 'cliente' && cita['estado'] == 'pendiente')
              Column(
                children: [
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelarCita(cita),
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text(
                        'Cancelar cita',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _finalizarCita(Map<String, dynamic> cita) async {
    try {
      Navigator.pop(context);

      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado');

      final idToken = await user.getIdToken();

      final url = Uri.parse('$apiBaseUrl/citas/${cita['id']}');

      print('🔄 Actualizando estado de cita: ${cita['id']}');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'estado': 'completada',
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

  Future<void> _cancelarCita(Map<String, dynamic> cita) async {
    // Mostrar diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: const Text(
          '¿Estás seguro que deseas cancelar esta cita?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, mantener'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      Navigator.pop(context); // Cerrar el bottom sheet

      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado');

      final idToken = await user.getIdToken();

      final url = Uri.parse('$apiBaseUrl/citas/${cita['id']}');

      print('🔄 Cancelando cita: ${cita['id']}');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      print('📥 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        await _cargarCitasReales();

        setState(() => _isLoading = false);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cita cancelada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error cancelando cita: $e');
      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cancelar: ${e.toString()}'),
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryOrange, size: 20),
          ),
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
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    final days = [
      'Domingo',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado'
    ];
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    return '${days[date.weekday % 7]}, ${date.day} de ${months[date.month - 1]}';
  }

  String _formatDateLong(DateTime date) {
    final days = [
      'Domingo',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado'
    ];
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    return '${days[date.weekday % 7]}, ${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getStatusText(String? estado) {
    switch (estado) {
      case 'confirmada':
        return 'Confirmada';
      case 'completada':
        return 'Completada';
      case 'pendiente':
        return 'Pendiente';
      case 'cancelada':
        return 'Cancelada';
      default:
        return 'Desconocido';
    }
  }
}
