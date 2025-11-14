import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';

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

      // Cargar servicios
      final serviciosUrl = Uri.parse('$apiBaseUrl/api/servicios?comercio_id=${widget.comercioId}');
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
          _servicios = serviciosData.map((s) => s as Map<String, dynamic>).toList();
        });
      }

      // Cargar horarios
      final horariosUrl = Uri.parse('$apiBaseUrl/api/horarios?comercio_id=${widget.comercioId}');
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
          _horarios = horariosData.map((h) => h as Map<String, dynamic>).toList();
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
      print('🔍 Cargando categorías desde API...');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ Usuario no autenticado');
        _usarCategoriasFallback();
        return;
      }

      final idToken = await user.getIdToken();
      
      final url = Uri.parse('$apiBaseUrl/api/categorias-servicio');
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
          return {
            'id': data['id'] as String,
            'nombre': data['nombre'] ?? data['id'],
            'icon': data['icon'] ?? '🎨',
            'servicios_sugeridos': data['servicios_sugeridos'] ?? [],
          };
        }).toList();

        categoriasList.sort((a, b) => 
          (a['nombre'] as String).compareTo(b['nombre'] as String)
        );

        setState(() {
          _categorias = categoriasList;
        });

        print('✅ ${_categorias.length} categorías cargadas desde API');
        
        for (var cat in _categorias) {
          final sugeridos = cat['servicios_sugeridos'] as List<dynamic>?;
          if (sugeridos != null && sugeridos.isNotEmpty) {
            print('   ${cat['nombre']}: ${sugeridos.length} servicios sugeridos');
          }
        }
      } else {
        print('⚠️ Error al cargar categorías: ${response.statusCode}');
        _usarCategoriasFallback();
      }
    } catch (e) {
      print('❌ Error cargando categorías: $e');
      _usarCategoriasFallback();
    }
  }

  void _usarCategoriasFallback() {
    setState(() {
      _categorias = [
        {'id': 'coloracion', 'nombre': 'Coloración', 'icon': '🎨', 'servicios_sugeridos': []},
        {'id': 'corte', 'nombre': 'Corte', 'icon': '✂️', 'servicios_sugeridos': []},
        {'id': 'depilacion', 'nombre': 'Depilación', 'icon': '💆', 'servicios_sugeridos': []},
        {'id': 'facial', 'nombre': 'Facial', 'icon': '✨', 'servicios_sugeridos': []},
        {'id': 'maquillaje', 'nombre': 'Maquillaje', 'icon': '💄', 'servicios_sugeridos': []},
        {'id': 'masajes', 'nombre': 'Masajes', 'icon': '💆‍♀️', 'servicios_sugeridos': []},
        {'id': 'tratamientos', 'nombre': 'Tratamientos', 'icon': '🧖', 'servicios_sugeridos': []},
        {'id': 'unas', 'nombre': 'Uñas', 'icon': '💅', 'servicios_sugeridos': []},
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF111418)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Configurar Servicios y Horarios',
            style: TextStyle(
              color: Color(0xFF111418),
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFFEA963A),
            unselectedLabelColor: Color(0xFF637588),
            indicatorColor: Color(0xFFEA963A),
            tabs: [
              Tab(text: 'Servicios'),
              Tab(text: 'Horarios'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA963A)))
            : TabBarView(
                children: [
                  _buildServiciosTab(),
                  _buildHorariosTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildServiciosTab() {
    return Column(
      children: [
        Expanded(
          child: _servicios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.design_services_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No tienes servicios', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _servicios.length,
                  itemBuilder: (context, index) {
                    final servicio = _servicios[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          servicio['nombre'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${servicio['categoria_id']} • ${servicio['duracion_min']} min • L${servicio['precio']?.toStringAsFixed(2)}',
                            ),
                            if (servicio['descripcion'] != null && (servicio['descripcion'] as String).isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                servicio['descripcion'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarServicio(servicio['id']),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _agregarServicio,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Agregar Servicio', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA963A),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorariosTab() {
    return Column(
      children: [
        Expanded(
          child: _horarios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No tienes horarios', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _horarios.length,
                  itemBuilder: (context, index) {
                    final horario = _horarios[index];
                    final diaSemana = horario['dia_semana'] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEA963A).withOpacity(0.1),
                          child: Text(
                            _diasSemana[diaSemana].substring(0, 1),
                            style: const TextStyle(
                              color: Color(0xFFEA963A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          _diasSemana[diaSemana],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${horario['hora_inicio']} - ${horario['hora_fin']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarHorario(horario['id']),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _agregarHorario,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Agregar Horario', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA963A),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _agregarServicio() async {
    if (_categorias.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cargando categorías...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController();
    String categoriaSeleccionada = _categorias[0]['id'] as String;
    int duracion = 30;
    double precio = 0;
    List<String> serviciosSugeridosActuales = [];
    String? servicioSugeridoSeleccionado;
    
    // Cargar servicios sugeridos de la primera categoría
    final primeraCategoria = _categorias[0];
    final sugeridosData = primeraCategoria['servicios_sugeridos'] as List<dynamic>?;
    if (sugeridosData != null) {
      serviciosSugeridosActuales = sugeridosData.map((s) => s.toString()).toList();
    }

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
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
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: _categorias.map<DropdownMenuItem<String>>((cat) {
                      return DropdownMenuItem<String>(
                        value: cat['id'] as String,
                        child: Row(
                          children: [
                            Text(cat['icon'] as String? ?? '📋', style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(cat['nombre'] as String? ?? 'Sin nombre'),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setStateDialog(() {
                          categoriaSeleccionada = v;
                          
                          final categoriaData = _categorias.firstWhere(
                            (c) => c['id'] == v,
                            orElse: () => <String, dynamic>{},
                          );
                          
                          final sugeridosData = categoriaData['servicios_sugeridos'] as List<dynamic>?;
                          if (sugeridosData != null) {
                            serviciosSugeridosActuales = sugeridosData.map((s) => s.toString()).toList();
                          } else {
                            serviciosSugeridosActuales = [];
                          }
                          
                          servicioSugeridoSeleccionado = null;
                          nombreController.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  if (serviciosSugeridosActuales.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: servicioSugeridoSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Servicio sugerido (opcional)',
                        hintText: 'Selecciona un servicio',
                      ),
                      items: serviciosSugeridosActuales.map((servicio) {
                        return DropdownMenuItem<String>(
                          value: servicio,
                          child: Text(servicio),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setStateDialog(() {
                          servicioSugeridoSeleccionado = v;
                          if (v != null) {
                            nombreController.text = v;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'O escribe tu propio servicio:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                  ],
                  
                  TextFormField(
                    controller: nombreController,
                    decoration: InputDecoration(
                      labelText: serviciosSugeridosActuales.isEmpty 
                          ? 'Nombre del servicio'
                          : 'Nombre personalizado',
                      hintText: 'Ej. Corte de cabello',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'El nombre es requerido';
                      }
                      return null;
                    },
                    onChanged: (v) {
                      if (v.isNotEmpty && servicioSugeridoSeleccionado != null) {
                        setStateDialog(() {
                          servicioSugeridoSeleccionado = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Duración (min)'),
                    keyboardType: TextInputType.number,
                    initialValue: '30',
                    validator: (v) => int.tryParse(v ?? '') == null ? 'Inválido' : null,
                    onSaved: (v) => duracion = int.tryParse(v ?? '30') ?? 30,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Precio (L)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => double.tryParse(v ?? '') == null ? 'Inválido' : null,
                    onSaved: (v) => precio = double.tryParse(v ?? '0') ?? 0,
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
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  formKey.currentState?.save();
                  
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    final idToken = await user.getIdToken();
                    
                    final payload = {
                      'usuario_id': user.uid,
                      'comercio_id': widget.comercioId,
                      'categoria_id': categoriaSeleccionada,
                      'nombre': nombreController.text,
                      'duracion_min': duracion,
                      'precio': precio,
                      'moneda': 'HNL',
                      'activo': true,
                    };

                    print('📤 Enviando servicio: ${json.encode(payload)}');

                    final url = Uri.parse('$apiBaseUrl/api/servicios');
                    final response = await http.post(
                      url,
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $idToken',
                      },
                      body: json.encode(payload),
                    );

                    print('📥 Response: ${response.statusCode}');

                    if (response.statusCode == 201) {
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    } else {
                      throw Exception('Error ${response.statusCode}: ${response.body}');
                    }
                  } catch (e) {
                    print('❌ Error: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA963A)),
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    nombreController.dispose();
    if (resultado == true) await _cargarDatos();
  }

  Future<void> _agregarHorario() async {
    int diaSeleccionado = 1;
    TimeOfDay horaInicio = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay horaFin = const TimeOfDay(hour: 18, minute: 0);

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Agregar Horario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: diaSeleccionado,
                decoration: const InputDecoration(labelText: 'Día'),
                items: List.generate(7, (index) {
                  return DropdownMenuItem(value: index, child: Text(_diasSemana[index]));
                }),
                onChanged: (v) {
                  if (v != null) {
                    setStateDialog(() => diaSeleccionado = v);
                  }
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Hora de inicio'),
                trailing: Text(horaInicio.format(context)),
                onTap: () async {
                  final hora = await showTimePicker(context: context, initialTime: horaInicio);
                  if (hora != null) setStateDialog(() => horaInicio = hora);
                },
              ),
              ListTile(
                title: const Text('Hora de cierre'),
                trailing: Text(horaFin.format(context)),
                onTap: () async {
                  final hora = await showTimePicker(context: context, initialTime: horaFin);
                  if (hora != null) setStateDialog(() => horaFin = hora);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
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
                    'hora_inicio': '${horaInicio.hour.toString().padLeft(2, '0')}:${horaInicio.minute.toString().padLeft(2, '0')}',
                    'hora_fin': '${horaFin.hour.toString().padLeft(2, '0')}:${horaFin.minute.toString().padLeft(2, '0')}',
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

                  if (response.statusCode == 201) {
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA963A)),
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) await _cargarDatos();
  }

  Future<void> _eliminarServicio(String servicioId) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
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
            const SnackBar(content: Text('✅ Eliminado'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _eliminarHorario(String horarioId) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
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
            const SnackBar(content: Text('✅ Eliminado'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}