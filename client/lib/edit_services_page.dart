import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'theme/app_theme.dart';

class EditServicesPage extends StatefulWidget {
  final String comercioId;

  const EditServicesPage({
    Key? key,
    required this.comercioId,
  }) : super(key: key);

  @override
  State<EditServicesPage> createState() => _EditServicesPageState();
}

class _EditServicesPageState extends State<EditServicesPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _servicios = [];
  List<Map<String, dynamic>> _horarios = [];
  List<Map<String, dynamic>> _categorias = [];

  final List<String> _diasSemana = [
    'Domingo',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      await _cargarCategorias();

      final serviciosUrl =
          Uri.parse('$apiBaseUrl/api/servicios?comercio_id=${widget.comercioId}');
      final serviciosResponse = await http.get(
        serviciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (serviciosResponse.statusCode == 200) {
        final List<dynamic> serviciosData = json.decode(serviciosResponse.body);
        setState(() {
          _servicios =
              serviciosData.map((s) => s as Map<String, dynamic>).toList();
        });
      }

      final horariosUrl =
          Uri.parse('$apiBaseUrl/api/horarios?comercio_id=${widget.comercioId}');
      final horariosResponse = await http.get(
        horariosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (horariosResponse.statusCode == 200) {
        final List<dynamic> horariosData = json.decode(horariosResponse.body);
        setState(() {
          _horarios =
              horariosData.map((h) => h as Map<String, dynamic>).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarCategorias() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _usarCategoriasFallback();
        return;
      }

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/categorias_servicio');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> categoriasData = json.decode(response.body);

        final categoriasList = categoriasData.map((data) {
          final sugeridos = data['servicios_sugeridos'];

          return {
            'id': data['id'] as String,
            'nombre': data['nombre'] ?? data['id'],
            'icon': data['icon'] ?? '🎨',
            'servicios_sugeridos': sugeridos is List ? sugeridos : [],
          };
        }).toList();

        categoriasList.sort(
          (a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String),
        );
        setState(() => _categorias = categoriasList);
      } else {
        _usarCategoriasFallback();
      }
    } catch (e) {
      print('❌ Error: $e');
      _usarCategoriasFallback();
    }
  }

  void _usarCategoriasFallback() {
    setState(() {
      _categorias = [
        {
          'id': 'coloracion',
          'nombre': 'Coloración',
          'icon': '🎨',
          'servicios_sugeridos': []
        },
        {
          'id': 'corte',
          'nombre': 'Corte',
          'icon': '✂️',
          'servicios_sugeridos': []
        },
        {
          'id': 'depilacion',
          'nombre': 'Depilación',
          'icon': '💆',
          'servicios_sugeridos': []
        },
        {
          'id': 'facial',
          'nombre': 'Facial',
          'icon': '✨',
          'servicios_sugeridos': []
        },
        {
          'id': 'maquillaje',
          'nombre': 'Maquillaje',
          'icon': '💄',
          'servicios_sugeridos': []
        },
        {
          'id': 'masajes',
          'nombre': 'Masajes',
          'icon': '💆‍♀️',
          'servicios_sugeridos': []
        },
        {
          'id': 'tratamientos',
          'nombre': 'Tratamientos',
          'icon': '🧖',
          'servicios_sugeridos': []
        },
        {
          'id': 'unas',
          'nombre': 'Uñas',
          'icon': '💅',
          'servicios_sugeridos': []
        },
      ];
    });
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBackground,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Servicios y Horarios',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: const TabBar(
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Color(0xFF9CA3AF),
            indicatorColor: AppTheme.primaryOrange,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Servicios'),
              Tab(text: 'Horarios'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryOrange,
                ),
              )
            : TabBarView(
                children: [
                  _buildServiciosTab(),
                  _buildHorariosTab(),
                ],
              ),
      ),
    );
  }

  TextStyle get _sectionTitleStyle => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );

  // ---------- Servicios (grid estilo cards) ----------

  Widget _buildServiciosTab() {
    final widgets = <Widget>[
      ..._servicios.map(
        (servicio) => _ServicioCard(
          nombre: servicio['nombre'] ?? '',
          categoriaId: servicio['categoria_id'],
          duracionMin: servicio['duracion_min'],
          precio: (servicio['precio'] ?? 0).toDouble(),
          icon: _getIconoCategoria(servicio['categoria_id']),
          onDelete: () => _eliminarServicio(servicio['id']),
        ),
      ),
      _AddServicioCard(onTap: _agregarServicio),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gestionar Servicios', style: _sectionTitleStyle),
          const SizedBox(height: 16),
          Expanded(
            child: _servicios.isEmpty
                ? Center(
                    child: _AddServicioCard(
                      onTap: _agregarServicio,
                    ),
                  )
                : GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.78,
                    children: widgets,
                  ),
          ),
        ],
      ),
    );
  }

  String _getIconoCategoria(String? categoriaId) {
    if (categoriaId == null) return '💇‍♀️';
    final cat = _categorias
        .cast<Map<String, dynamic>?>()
        .firstWhere((c) => c?['id'] == categoriaId, orElse: () => null);
    return (cat?['icon'] as String?) ?? '💇‍♀️';
  }

  // ---------- Horarios (lista estilo mock) ----------

  Widget _buildHorariosTab() {
    final Map<int, Map<String, dynamic>> horariosPorDia = {};
    for (final h in _horarios) {
      final int dia = (h['dia_semana'] ?? 0) as int;
      horariosPorDia[dia] = h;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gestionar Horarios de Atención', style: _sectionTitleStyle),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: 7,
              itemBuilder: (context, index) {
                final horario = horariosPorDia[index];
                final bool tieneHorario = horario != null;

                final String diaTexto = _diasSemana[index];
                final String horaInicio =
                    tieneHorario ? (horario['hora_inicio'] ?? '') : '';
                final String horaFin =
                    tieneHorario ? (horario['hora_fin'] ?? '') : '';
                final bool activo =
                    tieneHorario ? (horario['activo'] ?? true) : false;

                return _HorarioCard(
                  dia: diaTexto,
                  horaInicio: horaInicio,
                  horaFin: horaFin,
                  activo: activo,
                  tieneHorario: tieneHorario,
                  onDelete:
                      tieneHorario ? () => _eliminarHorario(horario['id']) : null,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _agregarHorario,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 6,
              ),
              child: const Text(
                'Agregar horario',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- LÓGICA ORIGINAL (no tocar, solo rediseño visual) ----------

  Future<void> _agregarServicio() async {
    if (_categorias.isEmpty) return;

    final formKey = GlobalKey<FormState>();
    String categoriaSeleccionada = _categorias[0]['id'] as String;
    String? servicioSeleccionado;
    String descripcion = '';
    int duracion = 30;
    double precio = 0;
    List<String> serviciosSugeridosActuales = [];

    final sugeridosData =
        _categorias[0]['servicios_sugeridos'] as List<dynamic>?;
    if (sugeridosData != null) {
      serviciosSugeridosActuales =
          sugeridosData.map((s) => s.toString()).toList();
    }

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Agregar Servicio'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: _categorias
                        .map<DropdownMenuItem<String>>(
                          (cat) => DropdownMenuItem<String>(
                            value: cat['id'] as String,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    cat['icon'] as String? ?? '',
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.category,
                                        size: 28,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat['nombre'] as String? ?? 'Sin nombre',
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setStateDialog(() {
                          categoriaSeleccionada = v;
                          servicioSeleccionado = null;
                          final categoriaData = _categorias.firstWhere(
                            (c) => c['id'] == v,
                            orElse: () => <String, dynamic>{},
                          );
                          final sugeridosData =
                              categoriaData['servicios_sugeridos']
                                  as List<dynamic>?;
                          serviciosSugeridosActuales = sugeridosData != null
                              ? sugeridosData.map((s) => s.toString()).toList()
                              : [];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  serviciosSugeridosActuales.isNotEmpty
                      ? DropdownButtonFormField<String>(
                          value: servicioSeleccionado,
                          decoration: const InputDecoration(
                            labelText: 'Servicio',
                            border: OutlineInputBorder(),
                            hintText: 'Selecciona un servicio',
                          ),
                          items: serviciosSugeridosActuales
                              .map(
                                (servicio) => DropdownMenuItem<String>(
                                  value: servicio,
                                  child: Text(servicio),
                                ),
                              )
                              .toList(),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Debes seleccionar un servicio'
                              : null,
                          onChanged: (v) =>
                              setStateDialog(() => servicioSeleccionado = v),
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No hay servicios disponibles para esta '
                                  'categoría.\nContacta al administrador.',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                      hintText: 'Describe el servicio...',
                    ),
                    maxLines: 2,
                    onSaved: (v) => descripcion = v ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Duración (minutos)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: '30',
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Requerido'
                        : (int.tryParse(v) == null
                            ? 'Debe ser un número'
                            : null),
                    onSaved: (v) =>
                        duracion = int.tryParse(v ?? '30') ?? 30,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Precio (L)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      prefixText: 'L ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Requerido'
                        : (double.tryParse(v) == null
                            ? 'Debe ser un número'
                            : null),
                    onSaved: (v) =>
                        precio = double.tryParse(v ?? '0') ?? 0,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: serviciosSugeridosActuales.isEmpty
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        formKey.currentState?.save();
                        if (servicioSeleccionado == null ||
                            servicioSeleccionado!.isEmpty) {
                          return;
                        }

                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;

                          final idToken = await user.getIdToken();
                          final payload = {
                            'usuario_id': user.uid,
                            'comercio_id': widget.comercioId,
                            'categoria_id': categoriaSeleccionada,
                            'nombre': servicioSeleccionado,
                            'descripcion':
                                descripcion.isEmpty ? null : descripcion,
                            'duracion_min': duracion,
                            'precio': precio,
                            'moneda': 'HNL',
                            'activo': true,
                          };

                          final url = Uri.parse('$apiBaseUrl/api/servicios');
                          final response = await http.post(
                            url,
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer $idToken',
                            },
                            body: json.encode(payload),
                          );

                          if (response.statusCode == 201 &&
                              context.mounted) {
                            Navigator.pop(context, true);
                          }
                        } catch (e) {
                          print('❌ Error: $e');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA963A),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) await _cargarDatos();
  }

  Future<void> _agregarHorario() async {
    int diaSeleccionado = 1;
    TimeOfDay horaInicio = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay horaFin = const TimeOfDay(hour: 18, minute: 0);

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            contentPadding: EdgeInsets.zero,
            content: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EA),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    offset: const Offset(0, 16),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Agregar horario',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona el día y define la hora de inicio y cierre '
                    'para la atención del salón.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<int>(
                    value: diaSeleccionado,
                    decoration: InputDecoration(
                      labelText: 'Día',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryOrange,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: List.generate(
                      7,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text(_diasSemana[index]),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) {
                        setStateDialog(() => diaSeleccionado = v);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      final hora = await showTimePicker(
                        context: context,
                        initialTime: horaInicio,
                      );
                      if (hora != null) {
                        setStateDialog(() => horaInicio = hora);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Hora de inicio',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            horaInicio.format(context),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      final hora = await showTimePicker(
                        context: context,
                        initialTime: horaFin,
                      );
                      if (hora != null) {
                        setStateDialog(() => horaFin = hora);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Hora de cierre',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            horaFin.format(context),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;
                            final idToken = await user.getIdToken();
                            final payload = {
                              'comercio_id': widget.comercioId,
                              'usuario_id': user.uid,
                              'dia_semana': diaSeleccionado,
                              'hora_inicio':
                                  '${horaInicio.hour.toString().padLeft(2, '0')}:${horaInicio.minute.toString().padLeft(2, '0')}',
                              'hora_fin':
                                  '${horaFin.hour.toString().padLeft(2, '0')}:${horaFin.minute.toString().padLeft(2, '0')}',
                              'activo': true,
                            };
                            final url = Uri.parse('$apiBaseUrl/api/horarios');
                            final response = await http.post(
                              url,
                              headers: {
                                'Content-Type': 'application/json',
                                'Authorization': 'Bearer $idToken',
                              },
                              body: json.encode(payload),
                            );
                            if (response.statusCode == 201 &&
                                context.mounted) {
                              Navigator.pop(context, true);
                            }
                          } catch (e) {}
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'Guardar',
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
      ),
    );

    if (resultado == true) await _cargarDatos();
  }

  Future<void> _eliminarServicio(String servicioId) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Servicio'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final idToken = await user.getIdToken();
        await http.delete(
          Uri.parse('$apiBaseUrl/api/servicios/$servicioId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );
        await _cargarDatos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {}
    }
  }

  Future<void> _eliminarHorario(String horarioId) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Horario'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final idToken = await user.getIdToken();
        await http.delete(
          Uri.parse('$apiBaseUrl/api/horarios/$horarioId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );
        await _cargarDatos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {}
    }
  }
}

// ---------- WIDGETS DE UI ----------

class _ServicioCard extends StatelessWidget {
  final String nombre;
  final String? categoriaId;
  final int? duracionMin;
  final double precio;
  final String icon;
  final VoidCallback onDelete;

  const _ServicioCard({
    Key? key,
    required this.nombre,
    required this.categoriaId,
    required this.duracionMin,
    required this.precio,
    required this.icon,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final duracionTexto = duracionMin != null ? '${duracionMin!} min' : '';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            offset: const Offset(0, 12),
            blurRadius: 24,
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ícono centrado y grande
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272F),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.network(
                        icon,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.category,
                              color: AppTheme.primaryOrange,
                              size: 36,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Nombre del servicio centrado
                Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                // Precio y duración
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'L${precio.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (duracionTexto.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            duracionTexto,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Botón eliminar arriba a la derecha
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddServicioCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddServicioCard({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DottedBorderContainer(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF27272F),
            child: Icon(
              Icons.add,
              color: AppTheme.primaryOrange,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Añadir Servicio',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Toca para añadir',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class DottedBorderContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const DottedBorderContainer({
    Key? key,
    required this.child,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF3F3F46),
            width: 1.4,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _HorarioCard extends StatelessWidget {
  final String dia;
  final String horaInicio;
  final String horaFin;
  final bool activo;
  final bool tieneHorario;
  final VoidCallback? onDelete;

  const _HorarioCard({
    Key? key,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
    required this.activo,
    required this.tieneHorario,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String textoRango =
        (tieneHorario && horaInicio.isNotEmpty && horaFin.isNotEmpty)
            ? '$horaInicio - $horaFin'
            : 'Sin horario configurado';

    final Color cardColor = tieneHorario
        ? AppTheme.cardBackground
        : AppTheme.cardBackground.withOpacity(0.7);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dia,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Switch(
                value: tieneHorario ? activo : false,
                onChanged: tieneHorario
                    ? (_) {
                        // lógica futura para activar/desactivar
                      }
                    : null,
                activeColor: AppTheme.primaryOrange,
                inactiveTrackColor: const Color(0xFF3F3F46),
              ),
              if (tieneHorario && onDelete != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: onDelete,
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.grey.shade700,
                  ),
                  onPressed: null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            textoRango,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}