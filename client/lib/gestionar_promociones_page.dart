import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'galeria_salon_page.dart'; // 👈 NUEVO

class GestionarPromocionesPage extends StatefulWidget {
  const GestionarPromocionesPage({Key? key}) : super(key: key);

  @override
  State<GestionarPromocionesPage> createState() =>
      _GestionarPromocionesPageState();
}

class _GestionarPromocionesPageState extends State<GestionarPromocionesPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _promociones = [];
  String? _comercioId;
  List<Map<String, dynamic>> _servicios = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      print('👤 Usuario autenticado: ${user.uid}');
      print('📧 Email del usuario: ${user.email}');

      // 1. Obtener comercio del salón
      final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
      print('🌐 Consultando comercios: $comerciosUrl');

      final comerciosResponse = await http.get(
        comerciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      print('📡 Respuesta comercios: ${comerciosResponse.statusCode}');

      if (comerciosResponse.statusCode == 200) {
        final List<dynamic> comercios = json.decode(comerciosResponse.body);
        print('🏪 Total de comercios en BD: ${comercios.length}');

        for (var c in comercios) {
          print(
              '  - Comercio: ${c['nombre']} | ID: ${c['id']} | Email: ${c['email']} | UID_negocio: ${c['uid_negocio']}');
        }

        final miComercio = comercios.firstWhere(
          (c) =>
              c['uid_negocio'] == user.uid ||
              c['usuario_id'] == user.uid ||
              c['email'] == user.email,
          orElse: () => null,
        );

        if (miComercio != null) {
          _comercioId = miComercio['id'];
          print(
              '✅ Mi comercio encontrado: ${miComercio['nombre']} (ID: $_comercioId)');

          // 2. Obtener servicios del comercio (MISMA RUTA QUE EN SalonProfilePage)
          final serviciosUrl = Uri.parse(
              '$apiBaseUrl/api/servicios?comercio_id=$_comercioId');
          print('🔍 Buscando servicios: $serviciosUrl');

          final serviciosResponse = await http.get(
            serviciosUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          );

          print('📋 Respuesta servicios: ${serviciosResponse.statusCode}');
          print('📄 Body servicios: ${serviciosResponse.body}');

          if (serviciosResponse.statusCode == 200) {
            final List<dynamic> serviciosList =
                json.decode(serviciosResponse.body);
            _servicios = serviciosList
                .map((s) => s as Map<String, dynamic>)
                .toList();
            print('✅ Servicios cargados: ${_servicios.length}');
            for (var s in _servicios) {
              print(
                  '  - Servicio: ${s['nombre']} | ID: ${s['id']} | Precio: ${s['precio']}');
            }
          } else {
            print(
                '❌ Error obteniendo servicios: ${serviciosResponse.body}');
          }

          // 3. Obtener promociones del comercio
          final promocionesUrl =
              Uri.parse('$apiBaseUrl/api/promociones/comercio/$_comercioId');
          print('🎁 Buscando promociones: $promocionesUrl');

          final promocionesResponse = await http.get(
            promocionesUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
          );

          print(
              '📡 Respuesta promociones: ${promocionesResponse.statusCode}');

          if (promocionesResponse.statusCode == 200) {
            final promocionesList =
                json.decode(promocionesResponse.body) as List;
            _promociones =
                promocionesList.cast<Map<String, dynamic>>();
            print('✅ Promociones cargadas: ${_promociones.length}');
          } else {
            print(
                '❌ Error obteniendo promociones: ${promocionesResponse.body}');
          }
        } else {
          print('❌ No se encontró comercio para el usuario: ${user.uid}');
          print(
              '💡 Asegúrate de que el comercio tenga uid_negocio = ${user.uid}');
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error cargando datos: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gestionar Promociones',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : _comercioId == null
              ? _buildNoComercioState()
              : _promociones.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _promociones.length,
                      itemBuilder: (context, index) {
                        final promo = _promociones[index];
                        return _PromocionCard(
                          promocion: promo,
                          onEdit: () => _editarPromocion(promo),
                          onDelete: () =>
                              _eliminarPromocion(promo['id']),
                          onToggle: (activo) =>
                              _togglePromocion(promo['id'], activo),
                        );
                      },
                    ),
      // 👇 Quitamos el botón flotante para que solo quede el botón central
      floatingActionButton: null,
    );
  }

  Widget _buildNoComercioState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.store_outlined,
                size: 60,
                color: AppTheme.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Comercio no encontrado',
              style: AppTheme.heading2.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'No se encontró un comercio asociado a tu cuenta. Por favor, completa el registro de tu salón primero.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _cargarDatos(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Reintentar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              size: 60,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No tienes promociones activas',
            style: AppTheme.heading2.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 12),
          Text(
            'Crea tu primera promoción para atraer más clientes',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // 👇 Este se queda como ÚNICO botón de crear
          ElevatedButton.icon(
            onPressed: _crearPromocion,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Crear Promoción',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _crearPromocion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioPromocion(
        servicios: _servicios,
        comercioId: _comercioId!,
        onGuardar: () {
          _cargarDatos();
        },
      ),
    );
  }

  void _editarPromocion(Map<String, dynamic> promocion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioPromocion(
        servicios: _servicios,
        comercioId: _comercioId!,
        promocion: promocion,
        onGuardar: () {
          _cargarDatos();
        },
      ),
    );
  }

  Future<void> _eliminarPromocion(String promocionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text(
          '¿Eliminar promoción?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Esta acción no se puede deshacer',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/promociones/$promocionId');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Promoción eliminada'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _cargarDatos();
      }
    } catch (e) {
      print('❌ Error eliminando promoción: $e');
    }
  }

  Future<void> _togglePromocion(String promocionId, bool activo) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/promociones/$promocionId');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({'activo': activo}),
      );

      if (response.statusCode == 200) {
        _cargarDatos();
      }
    } catch (e) {
      print('❌ Error actualizando promoción: $e');
    }
  }
}

// ======================= CARD DE PROMOCIÓN =======================

class _PromocionCard extends StatelessWidget {
  final Map<String, dynamic> promocion;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggle;

  const _PromocionCard({
    required this.promocion,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Safely parse fecha_fin - handle both String and Timestamp
    DateTime fechaFin;
    try {
      if (promocion['fecha_fin'] is String) {
        fechaFin = DateTime.parse(promocion['fecha_fin']);
      } else {
        // If it's a Timestamp or Map, try to convert
        fechaFin = DateTime.parse(promocion['fecha_fin'].toString());
      }
    } catch (e) {
      print('⚠️ Error parsing fecha_fin: $e');
      fechaFin = DateTime.now().add(const Duration(days: 30)); // Default to 30 days from now
    }
    
    final esActiva = promocion['activo'] == true;
    final estaVigente = fechaFin.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header con switch
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '-${promocion['valor']}%',
                    style: const TextStyle(
                      color: AppTheme.primaryOrange,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Switch(
                  value: esActiva,
                  onChanged: estaVigente ? onToggle : null,
                  activeColor: AppTheme.primaryOrange,
                ),
              ],
            ),
          ),

          // Contenido
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promocion['servicio_nombre'] ?? 'Servicio',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (promocion['descripcion'] != null)
                  Text(
                    promocion['descripcion'],
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (promocion['precio_original'] != null) ...[
                      Text(
                        'L. ${promocion['precio_original']}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      'L. ${promocion['precio_con_descuento'] ?? '0.00'}',
                      style: const TextStyle(
                        color: AppTheme.primaryOrange,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Válida hasta ${DateFormat('dd/MM/yyyy').format(fechaFin)}',
                      style: TextStyle(
                        color: estaVigente
                            ? AppTheme.textSecondary
                            : AppTheme.errorRed,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botones de acción
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryOrange,
                      side: const BorderSide(color: AppTheme.primaryOrange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: const BorderSide(color: AppTheme.errorRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Eliminar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= FORMULARIO =======================

class _FormularioPromocion extends StatefulWidget {
  final List<Map<String, dynamic>> servicios;
  final String comercioId;
  final Map<String, dynamic>? promocion;
  final VoidCallback onGuardar;

  const _FormularioPromocion({
    required this.servicios,
    required this.comercioId,
    this.promocion,
    required this.onGuardar,
  });

  @override
  State<_FormularioPromocion> createState() => _FormularioPromocionState();
}

class _FormularioPromocionState extends State<_FormularioPromocion> {
  final _formKey = GlobalKey<FormState>();
  String? _servicioSeleccionado; // guarda el id del servicio en String
  final _descuentoController = TextEditingController();
  final _descripcionController = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _guardando = false;
  String? _fotoSeleccionada;

  @override
  void initState() {
    super.initState();
    if (widget.promocion != null) {
      _servicioSeleccionado =
          widget.promocion!['servicio_id']?.toString();
      _descuentoController.text =
          widget.promocion!['valor'].toString();
      _descripcionController.text =
          widget.promocion!['descripcion'] ?? '';
      _fechaInicio = DateTime.parse(widget.promocion!['fecha_inicio']);
      _fechaFin = DateTime.parse(widget.promocion!['fecha_fin']);
      _fotoSeleccionada = widget.promocion!['foto_url'];
    } else {
      _fechaInicio = DateTime.now();
      _fechaFin = DateTime.now().add(const Duration(days: 30));
    }
  }

  // 👇 NUEVO: selección de foto navegando a GaleriaSalonPage
  Future<void> _seleccionarFotoDesdeGaleria() async {
  if (widget.comercioId.isEmpty) return;

  final urlSeleccionada = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => GaleriaSalonPage(
        comercioId: widget.comercioId,
        modoSeleccion: true,        // 👈 IMPORTANTE
      ),
    ),
  );

  if (!mounted) return;

  if (urlSeleccionada != null && urlSeleccionada.isNotEmpty) {
    setState(() => _fotoSeleccionada = urlSeleccionada);
  }
}

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.promocion == null
                    ? 'Nueva Promoción'
                    : 'Editar Promoción',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Selector de servicio
              const Text(
                'Servicio',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              widget.servicios.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'No tienes servicios registrados. Primero debes agregar servicios.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _servicioSeleccionado,
                      dropdownColor: AppTheme.darkBackground,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.darkBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'Selecciona un servicio',
                        hintStyle: const TextStyle(
                            color: AppTheme.textSecondary),
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      items: widget.servicios
                          .map<DropdownMenuItem<String>>((servicio) {
                        final idStr = servicio['id'].toString();
                        return DropdownMenuItem<String>(
                          value: idStr,
                          child: Text(
                              servicio['nombre'] ?? 'Servicio sin nombre'),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _servicioSeleccionado = value),
                      validator: (value) =>
                          value == null ? 'Selecciona un servicio' : null,
                    ),
              const SizedBox(height: 20),

              // Descuento
              const Text(
                'Descuento (%)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descuentoController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  hintText: '20',
                  hintStyle:
                      const TextStyle(color: AppTheme.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixText: '%',
                  suffixStyle:
                      const TextStyle(color: AppTheme.textSecondary),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa el descuento';
                  }
                  final numVal = double.tryParse(value);
                  if (numVal == null || numVal <= 0 || numVal > 100) {
                    return 'Debe estar entre 1 y 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Foto del servicio
              const Text(
                'Foto del servicio (opcional)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_fotoSeleccionada != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _fotoSeleccionada!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: AppTheme.darkBackground,
                        child: const Icon(Icons.broken_image,
                            color: AppTheme.textSecondary),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _seleccionarFotoDesdeGaleria,
                      icon: const Icon(Icons.photo_library),
                      label: Text(_fotoSeleccionada == null
                          ? 'Seleccionar foto'
                          : 'Cambiar foto'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryOrange,
                        side: const BorderSide(
                            color: AppTheme.primaryOrange),
                      ),
                    ),
                  ),
                  if (_fotoSeleccionada != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () =>
                          setState(() => _fotoSeleccionada = null),
                      icon: const Icon(Icons.close,
                          color: AppTheme.errorRed),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Descripción
              const Text(
                'Descripción (opcional)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  hintText:
                      'Describe los detalles de la promoción...',
                  hintStyle:
                      const TextStyle(color: AppTheme.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Fechas
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha inicio',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final fecha = await showDatePicker(
                              context: context,
                              initialDate:
                                  _fechaInicio ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (fecha != null) {
                              setState(() => _fechaInicio = fecha);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.darkBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _fechaInicio != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(_fechaInicio!)
                                  : 'Seleccionar',
                              style: const TextStyle(
                                  color: AppTheme.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha fin',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final fecha = await showDatePicker(
                              context: context,
                              initialDate: _fechaFin ??
                                  DateTime.now()
                                      .add(const Duration(days: 30)),
                              firstDate:
                                  _fechaInicio ?? DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (fecha != null) {
                              setState(() => _fechaFin = fecha);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.darkBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _fechaFin != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(_fechaFin!)
                                  : 'Seleccionar',
                              style: const TextStyle(
                                  color: AppTheme.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(
                            color: AppTheme.textSecondary),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_guardando ||
                              widget.servicios.isEmpty)
                          ? null
                          : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        disabledBackgroundColor:
                            AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Guardar',
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
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      print('⚠️ Validación del formulario falló');
      setState(() => _guardando = false);
      return;
    }

    if (_servicioSeleccionado == null) {
      print('⚠️ No hay servicio seleccionado');
      setState(() => _guardando = false);
      return;
    }

    if (widget.servicios.isEmpty) {
      print('⚠️ Lista de servicios vacía');
      setState(() => _guardando = false);
      return;
    }

    setState(() => _guardando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ Usuario no autenticado');
        setState(() => _guardando = false);
        return;
      }

      final idToken = await user.getIdToken();
      print('✅ Token obtenido');

      // Obtener datos del servicio seleccionado
      final servicio = widget.servicios.firstWhere(
        (s) => s['id'].toString() == _servicioSeleccionado,
        orElse: () => throw Exception('Servicio no encontrado'),
      );

      print(
          '📋 Servicio seleccionado: ${servicio['nombre']} (${servicio['id']})');

      final descuento = double.parse(_descuentoController.text);
      final precioOriginalNum = servicio['precio'] ?? 0;
      final precioOriginal =
          (precioOriginalNum is num) ? precioOriginalNum.toDouble() : 0.0;
      final precioConDescuento =
          double.parse((precioOriginal * (1 - descuento / 100))
              .toStringAsFixed(2));

      final payload = {
        'comercio_id': widget.comercioId,
        'servicio_id': _servicioSeleccionado,
        'servicio_nombre': servicio['nombre'],
        'foto_url': _fotoSeleccionada ?? servicio['foto_url'],
        'descripcion': _descripcionController.text.trim(),
        'tipo_descuento': 'porcentaje',
        'valor': descuento,
        'precio_original': precioOriginal,
        'precio_con_descuento': precioConDescuento,
        'fecha_inicio': _fechaInicio!.toIso8601String(),
        'fecha_fin': _fechaFin!.toIso8601String(),
        'activo': true,
      };

      print('📦 Payload: ${json.encode(payload)}');

      final url = widget.promocion == null
          ? Uri.parse('$apiBaseUrl/api/promociones')
          : Uri.parse(
              '$apiBaseUrl/api/promociones/${widget.promocion!['id']}');

      print('🌐 URL: $url');
      print('🔧 Método: ${widget.promocion == null ? 'POST' : 'PUT'}');

      final response = widget.promocion == null
          ? await http.post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: json.encode(payload),
            )
          : await http.put(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: json.encode(payload),
            );

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Promoción guardada exitosamente');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.promocion == null
                  ? 'Promoción creada exitosamente'
                  : 'Promoción actualizada'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onGuardar();
        }
      } else {
        print(
            '❌ Error en la respuesta: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Error del servidor: ${response.statusCode}'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error guardando promoción: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }
}