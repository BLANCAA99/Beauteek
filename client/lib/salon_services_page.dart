import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inicio.dart';

class SalonServicesPage extends StatefulWidget {
  final String comercioId;
  final String uidNegocio;

  const SalonServicesPage({
    Key? key,
    required this.comercioId,
    required this.uidNegocio,
  }) : super(key: key);

  @override
  State<SalonServicesPage> createState() => _SalonServicesPageState();
}

class _SalonServicesPageState extends State<SalonServicesPage> {
  // 🎨 Colores de tema Beauteek
  static const Color _backgroundColor = Color(0xFF101013);
  static const Color _cardColor = Color(0xFF1B1F2A);
  static const Color _cardSoftColor = Color(0xFF171A23);
  static const Color _primaryOrange = Color(0xFFEA963A);
  static const Color _secondaryOrange = Color(0xFFFFB15C);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB8C0CC);

  bool _isLoading = true;
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _serviciosAgregados = [];

  List<Map<String, dynamic>> _horarios = List.generate(7, (index) => {
        'dia_semana': index,
        'hora_inicio': const TimeOfDay(hour: 9, minute: 0),
        'hora_fin': const TimeOfDay(hour: 18, minute: 0),
        'activo': index >= 1 && index <= 5,
      });

  final List<String> _diasSemana = [
    'Domingo',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado'
  ];

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  // Cargar categorías desde Firestore
  Future<void> _cargarCategorias() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categorias_servicio')
          .where('activo', isEqualTo: true)
          .get();

      setState(() {
        _categorias = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'nombre': data['nombre'] ?? '',
            'icon': data['icon'] ?? '📋',
            'servicios_sugeridos':
                List<String>.from(data['servicios_sugeridos'] ?? []),
          };
        }).toList();
        _isLoading = false;
      });

      print('✅ ${_categorias.length} categorías cargadas desde Firestore');
    } catch (e) {
      print('❌ Error cargando categorías: $e');
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar categorías')),
      );
    }
  }

  void _mostrarFormularioServicio(Map<String, dynamic> categoria) {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();
    final duracionController = TextEditingController(text: '30');
    final precioController = TextEditingController();

    final serviciosSugeridos =
        List<String>.from(categoria['servicios_sugeridos'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: _cardSoftColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        categoria['icon'],
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Agregar servicio de ${categoria['nombre']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Servicios sugeridos
                if (serviciosSugeridos.isNotEmpty) ...[
                  const Text(
                    'Servicios sugeridos',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: serviciosSugeridos.map((servicio) {
                      return ActionChip(
                        label: Text(servicio),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        backgroundColor: _primaryOrange,
                        onPressed: () {
                          nombreController.text = servicio;
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                ],

                // Nombre del servicio
                _buildBottomSheetField(
                  controller: nombreController,
                  label: 'Nombre del servicio *',
                  hint: serviciosSugeridos.isNotEmpty
                      ? 'Ej: ${serviciosSugeridos[0]}'
                      : 'Nombre del servicio',
                ),
                const SizedBox(height: 14),

                // Descripción
                _buildBottomSheetField(
                  controller: descripcionController,
                  label: 'Descripción (opcional)',
                  hint: 'Describe el servicio...',
                  maxLines: 2,
                  isRequired: false,
                ),
                const SizedBox(height: 14),

                // Duración y Precio
                Row(
                  children: [
                    Expanded(
                      child: _buildBottomSheetField(
                        controller: duracionController,
                        label: 'Duración (min) *',
                        hint: '30',
                        keyboardType: TextInputType.number,
                        icon: Icons.access_time,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBottomSheetField(
                        controller: precioController,
                        label: 'Precio (L) *',
                        hint: '350',
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        icon: Icons.attach_money,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.white24,
                          ),
                          foregroundColor: _textSecondary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 🔸 Botón con degradado
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (nombreController.text.isEmpty ||
                              duracionController.text.isEmpty ||
                              precioController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Completa todos los campos requeridos'),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _serviciosAgregados.add({
                              'categoria_id': categoria['id'],
                              'categoria_nombre': categoria['nombre'],
                              'categoria_icon': categoria['icon'],
                              'nombre': nombreController.text,
                              'descripcion':
                                  descripcionController.text.isEmpty
                                      ? null
                                      : descripcionController.text,
                              'duracion_min':
                                  int.parse(duracionController.text),
                              'precio':
                                  double.parse(precioController.text),
                              'moneda': 'HNL',
                              'activo': true,
                            });
                          });

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('✅ Servicio agregado exitosamente'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF9A825), // un poco más claro
                                Color(0xFFEF6C00), // más intenso
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Agregar',
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Campo reutilizable para el bottom sheet
  Widget _buildBottomSheetField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    IconData? icon,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.white54, size: 20)
                : null,
            filled: true,
            fillColor: _cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _primaryOrange),
            ),
          ),
        ),
      ],
    );
  }

  String _formatearHora(TimeOfDay hora) {
    final h = hora.hour.toString().padLeft(2, '0');
    final m = hora.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _seleccionarHora(int diaIndex, String tipo) async {
    final horario = _horarios[diaIndex];
    final horaInicial = tipo == 'inicio'
        ? horario['hora_inicio'] as TimeOfDay
        : horario['hora_fin'] as TimeOfDay;

    final TimeOfDay? horaNueva = await showTimePicker(
      context: context,
      initialTime: horaInicial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _primaryOrange,
              onPrimary: Colors.white,
              surface: _cardSoftColor,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: _cardSoftColor,
          ),
          child: child!,
        );
      },
    );

    if (horaNueva != null) {
      setState(() {
        _horarios[diaIndex]
            [tipo == 'inicio' ? 'hora_inicio' : 'hora_fin'] = horaNueva;
      });
    }
  }

  Future<void> _finalizarRegistro() async {
    if (_serviciosAgregados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Debes agregar al menos un servicio')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Sesión expirada');

      final idToken = await currentUser.getIdToken();

      // Preparar servicios sin los campos de UI
      final serviciosParaEnviar = _serviciosAgregados.map((s) => {
            'categoria_id': s['categoria_id'],
            'nombre': s['nombre'],
            'descripcion': s['descripcion'],
            'duracion_min': s['duracion_min'],
            'precio': s['precio'],
            'moneda': s['moneda'],
            'activo': s['activo'],
          }).toList();

      // Convertir TimeOfDay a String para enviar al servidor
      final horariosParaEnviar =
          _horarios.where((h) => h['activo'] == true).map((h) {
        final inicio = h['hora_inicio'] as TimeOfDay;
        final fin = h['hora_fin'] as TimeOfDay;
        return {
          'dia_semana': h['dia_semana'],
          'hora_inicio': _formatearHora(inicio),
          'hora_fin': _formatearHora(fin),
          'activo': true,
        };
      }).toList();

      final payload = {
        'comercioId': widget.comercioId,
        'horarios': horariosParaEnviar,
        'servicios': serviciosParaEnviar,
      };

      print('📤 Enviando servicios y horarios: ${json.encode(payload)}');

      final url = Uri.parse('$apiBaseUrl/comercios/register-salon-step4');
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

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: _cardSoftColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Column(
              children: [
                Icon(Icons.check_circle,
                    color: _primaryOrange, size: 64),
                SizedBox(height: 16),
                Text(
                  '¡Felicidades! 🎉',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: const Text(
              'Tu salón está activo y listo para recibir clientes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => InicioPage()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryOrange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Ir al inicio',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Error al finalizar registro');
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
    if (_isLoading && _categorias.isEmpty) {
      return const Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _primaryOrange),
              SizedBox(height: 16),
              Text(
                'Cargando categorías...',
                style: TextStyle(color: _textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: const BackButton(color: _textPrimary),
        title: const Text(
          'Servicios y Horarios',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                const Text(
                  'Selecciona una categoría',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Agrega los servicios que ofrece tu salón',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),

                // Grid de categorías
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: _categorias.length,
                  itemBuilder: (context, index) {
                    final categoria = _categorias[index];
                    final int cantidadServicios = _serviciosAgregados
                        .where(
                            (s) => s['categoria_id'] == categoria['id'])
                        .length;
                    final bool tieneServicios = cantidadServicios > 0;

                    return InkWell(
                      onTap: () => _mostrarFormularioServicio(categoria),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: tieneServicios
                                ? _primaryOrange
                                : Colors.white12,
                            width: tieneServicios ? 1.4 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icono naranja
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [_primaryOrange, _secondaryOrange],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  categoria['icon'],
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              categoria['nombre'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (tieneServicios)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _primaryOrange.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$cantidadServicios servicio${cantidadServicios == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: _secondaryOrange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              const Text(
                                'Sin servicios aún',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 22),

                // Servicios agregados
                if (_serviciosAgregados.isNotEmpty) ...[
                  const Text(
                    'Servicios agregados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._serviciosAgregados.asMap().entries.map((entry) {
                    final index = entry.key;
                    final servicio = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: _cardSoftColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Text(
                          servicio['categoria_icon'],
                          style: const TextStyle(fontSize: 26),
                        ),
                        title: Text(
                          servicio['nombre'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${servicio['duracion_min']} min • L${servicio['precio'].toStringAsFixed(2)}',
                          style:
                              const TextStyle(color: _textSecondary),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () {
                            setState(() {
                              _serviciosAgregados.removeAt(index);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Servicio eliminado'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 18),
                ],

                // Horarios
                const Text(
                  'Horarios de atención',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._horarios.map((horario) {
                  final dia = horario['dia_semana'] as int;
                  final activo = horario['activo'] as bool;
                  final inicio = horario['hora_inicio'] as TimeOfDay;
                  final fin = horario['hora_fin'] as TimeOfDay;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _cardSoftColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: activo
                            ? _primaryOrange.withOpacity(0.5)
                            : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _diasSemana[dia],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: activo
                                    ? _textPrimary
                                    : _textSecondary,
                              ),
                            ),
                            Switch(
                              value: activo,
                              activeColor: _primaryOrange,
                              inactiveTrackColor: Colors.white12,
                              onChanged: (value) {
                                setState(() {
                                  horario['activo'] = value;
                                });
                              },
                            ),
                          ],
                        ),
                        if (activo) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      _seleccionarHora(dia, 'inicio'),
                                  child: _buildTimeBox(
                                    label: 'Desde',
                                    value: inicio.format(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      _seleccionarHora(dia, 'fin'),
                                  child: _buildTimeBox(
                                    label: 'Hasta',
                                    value: fin.format(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Cerrado',
                            style: TextStyle(
                              color: _textSecondary,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // Botón finalizar registro
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _finalizarRegistro,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                  backgroundColor: _primaryOrange,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Finalizar registro (${_serviciosAgregados.length} '
                            '${_serviciosAgregados.length == 1 ? 'servicio' : 'servicios'})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Icon(Icons.access_time, size: 18, color: _secondaryOrange),
        ],
      ),
    );
  }
}
