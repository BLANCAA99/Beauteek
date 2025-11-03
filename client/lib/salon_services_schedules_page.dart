import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'inicio.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Modelo para manejar el estado de cada servicio
class PredefinedService {
  final String nombre;
  bool isSelected;
  final TextEditingController nombreController;
  final TextEditingController duracionController;
  final TextEditingController precioController;
  final bool isCustom;

  PredefinedService(
    this.nombre, {
    this.isSelected = false,
    this.isCustom = false,
  })  : nombreController = TextEditingController(),
        duracionController = TextEditingController(),
        precioController = TextEditingController();

  void dispose() {
    nombreController.dispose();
    duracionController.dispose();
    precioController.dispose();
  }
}

class SalonServicesSchedulesPage extends StatefulWidget {
  final String comercioId;
  final String uidNegocio;
  
  const SalonServicesSchedulesPage({
    Key? key,
    required this.comercioId,
    required this.uidNegocio,
  }) : super(key: key);

  @override
  _SalonServicesSchedulesPageState createState() => _SalonServicesSchedulesPageState();
}

class _SalonServicesSchedulesPageState extends State<SalonServicesSchedulesPage> {
  bool _isLoading = false;

  late Map<int, Map<String, dynamic>> _horarios;
  final List<PredefinedService> _servicios = [
    PredefinedService('Corte de Dama'),
    PredefinedService('Manicura'),
    PredefinedService('Pedicura'),
    PredefinedService('Tinte de Cabello'),
    PredefinedService('Masaje Relajante'),
    PredefinedService('Limpieza Facial'),
  ];

  final List<String> _diasSemana = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  @override
  void initState() {
    super.initState();
    _horarios = Map.fromEntries(_diasSemana.asMap().entries.map((entry) {
      final esFinDeSemana = entry.key == 0 || entry.key == 6;
      return MapEntry(entry.key, {
        'activo': !esFinDeSemana,
        'horaInicio': const TimeOfDay(hour: 9, minute: 0),
        'horaFin': const TimeOfDay(hour: 17, minute: 0),
      });
    }));
  }

  @override
  void dispose() {
    for (var servicio in _servicios) {
      servicio.dispose();
    }
    super.dispose();
  }

  Future<void> _submitDetails() async {
    final horariosData = _horarios.entries
        .where((entry) => entry.value['activo'] == true)
        .map((entry) {
      final horaInicio = entry.value['horaInicio'] as TimeOfDay;
      final horaFin = entry.value['horaFin'] as TimeOfDay;
      return {
        'dia_semana': entry.key,
        'hora_inicio': '${horaInicio.hour.toString().padLeft(2, '0')}:${horaInicio.minute.toString().padLeft(2, '0')}',
        'hora_fin': '${horaFin.hour.toString().padLeft(2, '0')}:${horaFin.minute.toString().padLeft(2, '0')}',
        'activo': true,
      };
    }).toList();

    if (horariosData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar al menos un día de atención.')),
      );
      return;
    }

    final serviciosSeleccionados = _servicios.where((s) {
      if (s.isCustom) {
        return s.nombreController.text.trim().isNotEmpty;
      }
      return s.isSelected;
    }).toList();

    if (serviciosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos un servicio.')),
      );
      return;
    }

    final serviciosData = serviciosSeleccionados.map((servicio) {
      final nombre = servicio.isCustom ? servicio.nombreController.text.trim() : servicio.nombre;
      final duracion = int.tryParse(servicio.duracionController.text.trim()) ?? 30;
      final precio = double.tryParse(servicio.precioController.text.trim()) ?? 0.0;
      return {
        'categoria_id': 'default', // TODO: Implementar categorías reales
        'nombre': nombre.isEmpty ? 'Servicio' : nombre,
        'descripcion': '',
        'duracion_min': duracion,
        'precio': precio,
        'moneda': 'HNL',
        'activo': true,
      };
    }).toList();

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Obtener el token de autenticación
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('No hay sesión activa');
      
      final idToken = await currentUser.getIdToken();

      // Llamar al API para el paso 3
      final payload = {
        'comercioId': widget.comercioId,
        'horarios': horariosData,
        'servicios': serviciosData,
      };

      final url = Uri.parse('$apiBaseUrl/comercios/register-salon-step3'); // Sin /api

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('¡Salón registrado con éxito! Tu negocio está activo.')));

        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        
        // Navegar al inicio y limpiar la pila de navegación
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => InicioPage()), // Quitado el const
          (Route<dynamic> route) => false,
        );
      } else {
        String msg = 'Error al guardar los detalles';
        try {
          final data = json.decode(response.body);
          msg = data['message'] ?? data['error'] ?? msg;
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Paso 3: Servicios y Horarios', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        children: [
          const SizedBox(height: 24),
          _buildSectionTitle('Horarios de Atención *'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: _diasSemana.asMap().entries.map((entry) {
                return _buildHorarioRow(entry.key, entry.value);
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Menú de Servicios *'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                const Row(
                  children: [
                    Expanded(flex: 4, child: Text('Servicio', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('Minutos', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('Precio', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const Divider(),
                for (var servicio in _servicios) _buildServicioRow(servicio),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir otro servicio'),
                  onPressed: () {
                    setState(() {
                      _servicios.add(PredefinedService('', isCustom: true, isSelected: true));
                    });
                  },
                )
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5B1A8),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Finalizar Registro', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildHorarioRow(int diaIndex, String diaNombre) {
    final horario = _horarios[diaIndex]!;
    return Row(
      children: [
        Checkbox(
          value: horario['activo'],
          onChanged: (value) => setState(() => horario['activo'] = value ?? false),
        ),
        Expanded(child: Text(diaNombre, style: const TextStyle(fontWeight: FontWeight.w500))),
        TextButton(
          onPressed: !horario['activo'] ? null : () async {
            final TimeOfDay? newTime = await showTimePicker(context: context, initialTime: horario['horaInicio']);
            if (newTime != null) setState(() => horario['horaInicio'] = newTime);
          },
          child: Text(horario['horaInicio'].format(context)),
        ),
        const Text('-'),
        TextButton(
          onPressed: !horario['activo'] ? null : () async {
            final TimeOfDay? newTime = await showTimePicker(context: context, initialTime: horario['horaFin']);
            if (newTime != null) setState(() => horario['horaFin'] = newTime);
          },
          child: Text(horario['horaFin'].format(context)),
        ),
      ],
    );
  }

  Widget _buildServicioRow(PredefinedService servicio) {
    if (servicio.isCustom) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Expanded(flex: 4, child: _buildTextField(servicio.nombreController, 'Servicio', isRequired: false)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _buildTextField(servicio.duracionController, '30', keyboardType: TextInputType.number, isRequired: false)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _buildTextField(servicio.precioController, '100', keyboardType: TextInputType.number, isRequired: false)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => setState(() {
                servicio.dispose();
                _servicios.remove(servicio);
              }),
            )
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(servicio.nombre),
              value: servicio.isSelected,
              onChanged: (bool? value) => setState(() => servicio.isSelected = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _buildTextField(servicio.duracionController, '30', keyboardType: TextInputType.number, isRequired: false, enabled: servicio.isSelected)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _buildTextField(servicio.precioController, '100', keyboardType: TextInputType.number, isRequired: false, enabled: servicio.isSelected)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {TextInputType? keyboardType, bool isRequired = true, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade200,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      validator: (v) => (isRequired && (v == null || v.isEmpty)) ? 'Requerido' : null,
    );
  }
}
