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
    'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'
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
            'servicios_sugeridos': List<String>.from(data['servicios_sugeridos'] ?? []),
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

    final serviciosSugeridos = List<String>.from(categoria['servicios_sugeridos'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      categoria['icon'],
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Agregar servicio de ${categoria['nombre']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Servicios sugeridos
                if (serviciosSugeridos.isNotEmpty) ...[
                  const Text(
                    'Servicios sugeridos:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: serviciosSugeridos.map((servicio) {
                      return ActionChip(
                        label: Text(servicio),
                        backgroundColor: const Color(0xFFEA963A).withOpacity(0.1),
                        onPressed: () {
                          nombreController.text = servicio;
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Nombre del servicio
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del servicio *',
                    hintText: serviciosSugeridos.isNotEmpty 
                        ? 'Ej: ${serviciosSugeridos[0]}'
                        : 'Nombre del servicio',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Descripción
                TextField(
                  controller: descripcionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: 'Describe el servicio...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Duración y Precio
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: duracionController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Duración (min) *',
                          prefixIcon: const Icon(Icons.access_time),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: precioController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Precio (L) *',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (nombreController.text.isEmpty ||
                              duracionController.text.isEmpty ||
                              precioController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Completa todos los campos requeridos'),
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
                              'descripcion': descripcionController.text.isEmpty 
                                  ? null 
                                  : descripcionController.text,
                              'duracion_min': int.parse(duracionController.text),
                              'precio': double.parse(precioController.text),
                              'moneda': 'HNL',
                              'activo': true,
                            });
                          });

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Servicio agregado exitosamente'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA963A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Agregar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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

  String _formatearHora(TimeOfDay hora) {
    final h = hora.hour.toString().padLeft(2, '0');
    final m = hora.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _seleccionarHora(int diaIndex, String tipo) async {
    final horario = _horarios[diaIndex];
    final horaInicial = tipo == 'inicio' ? horario['hora_inicio'] as TimeOfDay : horario['hora_fin'] as TimeOfDay;
    
    final TimeOfDay? horaNueva = await showTimePicker(
      context: context,
      initialTime: horaInicial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEA963A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (horaNueva != null) {
      setState(() {
        _horarios[diaIndex][tipo == 'inicio' ? 'hora_inicio' : 'hora_fin'] = horaNueva;
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
      final horariosParaEnviar = _horarios
          .where((h) => h['activo'] == true)
          .map((h) {
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

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 64),
                SizedBox(height: 16),
                Text(
                  '¡Felicidades! 🎉',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              'Tu salón está activo y listo para recibir clientes.',
              textAlign: TextAlign.center,
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => InicioPage()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA963A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ir al inicio',
                  style: TextStyle(color: Colors.white),
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFEA963A)),
              SizedBox(height: 16),
              Text('Cargando categorías...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Servicios y Horarios',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Selecciona una categoría',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Agrega los servicios que ofrece tu salón',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // Grid de categorías desde Firestore
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _categorias.length,
                  itemBuilder: (context, index) {
                    final categoria = _categorias[index];
                    final tieneServicios = _serviciosAgregados
                        .any((s) => s['categoria_id'] == categoria['id']);

                    return InkWell(
                      onTap: () => _mostrarFormularioServicio(categoria),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: tieneServicios
                              ? const Color(0xFFEA963A).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: tieneServicios
                                ? const Color(0xFFEA963A)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              categoria['icon'],
                              style: const TextStyle(fontSize: 40),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              categoria['nombre'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (tieneServicios) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA963A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_serviciosAgregados.where((s) => s['categoria_id'] == categoria['id']).length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Servicios agregados
                if (_serviciosAgregados.isNotEmpty) ...[
                  const Text(
                    'Servicios agregados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._serviciosAgregados.asMap().entries.map((entry) {
                    final index = entry.key;
                    final servicio = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Text(
                          servicio['categoria_icon'],
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          servicio['nombre'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${servicio['duracion_min']} min • L${servicio['precio'].toStringAsFixed(2)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
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
                  const SizedBox(height: 24),
                ],

                // Horarios con TimePicker
                const Text(
                  'Horarios de atención',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._horarios.map((horario) {
                  final dia = horario['dia_semana'] as int;
                  final activo = horario['activo'] as bool;
                  final inicio = horario['hora_inicio'] as TimeOfDay;
                  final fin = horario['hora_fin'] as TimeOfDay;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: activo ? const Color(0xFFFFF3E0) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _diasSemana[dia],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: activo ? Colors.black : Colors.grey,
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Switch(
                                value: activo,
                                activeColor: const Color(0xFFEA963A),
                                onChanged: (value) {
                                  setState(() {
                                    horario['activo'] = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        if (activo) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _seleccionarHora(dia, 'inicio'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFEA963A),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            inicio.format(context),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.access_time,
                                            color: Color(0xFFEA963A),
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _seleccionarHora(dia, 'fin'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFEA963A),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            fin.format(context),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.access_time,
                                            color: Color(0xFFEA963A),
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            'Cerrado',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
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

          // Botón finalizar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _finalizarRegistro,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA963A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Finalizar registro (${_serviciosAgregados.length} ${_serviciosAgregados.length == 1 ? 'servicio' : 'servicios'})',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
}