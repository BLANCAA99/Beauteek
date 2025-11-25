import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_constants.dart';
import 'theme/app_theme.dart';
import 'calendar_page.dart';

class PromocionesPage extends StatefulWidget {
  const PromocionesPage({Key? key}) : super(key: key);

  @override
  State<PromocionesPage> createState() => _PromocionesPageState();
}

class _PromocionesPageState extends State<PromocionesPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _promociones = [];
  String _categoriaSeleccionada = 'Todos';
  final List<String> _categorias = [
    'Todos',
    'Cabello',
    'Uñas',
    'Masajes',
    'Faciales',
  ];

  @override
  void initState() {
    super.initState();
    _cargarPromociones();
  }

  Future<void> _cargarPromociones() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/promociones');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Filtrar promociones activas y vigentes
        final now = DateTime.now();
        final promocionesActivas = data.where((promo) {
          if (promo['activo'] != true) return false;
          
          try {
            final fechaFin = DateTime.parse(promo['fecha_fin']);
            return fechaFin.isAfter(now);
          } catch (e) {
            return false;
          }
        }).toList();

        // Obtener detalles de comercios
        final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
        final comerciosResponse = await http.get(
          comerciosUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );

        Map<String, dynamic> comerciosMap = {};
        if (comerciosResponse.statusCode == 200) {
          final List<dynamic> comercios = json.decode(comerciosResponse.body);
          for (var comercio in comercios) {
            comerciosMap[comercio['id']] = comercio;
          }
        }

        // Enriquecer promociones con datos del comercio
        for (var promo in promocionesActivas) {
          final comercioId = promo['comercio_id'];
          if (comerciosMap.containsKey(comercioId)) {
            promo['comercio'] = comerciosMap[comercioId];
          }
        }

        setState(() {
          _promociones = promocionesActivas.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando promociones: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _promocionesFiltradas {
    if (_categoriaSeleccionada == 'Todos') {
      return _promociones;
    }
    return _promociones.where((promo) {
      final servicioNombre = (promo['servicio_nombre'] ?? '').toString().toLowerCase();
      final categoria = _categoriaSeleccionada.toLowerCase();
      return servicioNombre.contains(categoria);
    }).toList();
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
          'Promociones',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppTheme.textPrimary),
            onPressed: () {
              // TODO: Filtros avanzados
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de categorías
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categorias.length,
              itemBuilder: (context, index) {
                final categoria = _categorias[index];
                final isSelected = categoria == _categoriaSeleccionada;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _categoriaSeleccionada = categoria),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryOrange : AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Center(
                        child: Text(
                          categoria,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Medios de pago (opcional)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Medios de Pago',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MedioPagoChip(logo: 'VISA', color: const Color(0xFF1A1F71)),
                    const SizedBox(width: 12),
                    _MedioPagoChip(logo: 'MC', color: const Color(0xFFEB001B)),
                    const SizedBox(width: 12),
                    _MedioPagoChip(logo: 'AMEX', color: const Color(0xFF006FCF)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Banner "Agenda desde casa"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9500), Color(0xFFFF6B00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agenda desde casa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Reserva tus citas de belleza fácil y rápido.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Descubrir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Lista de promociones
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryOrange,
                    ),
                  )
                : _promocionesFiltradas.isEmpty
                    ? Center(
                        child: Text(
                          'No hay promociones disponibles',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _promocionesFiltradas.length,
                        itemBuilder: (context, index) {
                          final promo = _promocionesFiltradas[index];
                          return _PromocionCard(
                            promocion: promo,
                            onTap: () {
                              _mostrarDetallePromocion(promo);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetallePromocion(Map<String, dynamic> promo) {
    final comercio = promo['comercio'] as Map<String, dynamic>?;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con descuento
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '-${promo['valor']}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Nombre del servicio
            Text(
              promo['servicio_nombre'] ?? 'Servicio',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Nombre del comercio
            if (comercio != null)
              Text(
                comercio['nombre'] ?? 'Salón',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            const SizedBox(height: 16),
            
            // Precios
            Row(
              children: [
                if (promo['precio_original'] != null)
                  Text(
                    '€${promo['precio_original']}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                const SizedBox(width: 12),
                Text(
                  '€${promo['precio_con_descuento'] ?? '0.00'}',
                  style: const TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Descripción
            if (promo['descripcion'] != null)
              Text(
                promo['descripcion'],
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 24),
            
            // Botón de reservar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navegar a página de reserva
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalendarPage(
                        comercioId: promo['comercio_id'],
                        servicioId: promo['servicio_id'],
                        promocionId: promo['id'],
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Reservar Ahora',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedioPagoChip extends StatelessWidget {
  final String logo;
  final Color color;

  const _MedioPagoChip({required this.logo, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(
          logo,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _PromocionCard extends StatelessWidget {
  final Map<String, dynamic> promocion;
  final VoidCallback onTap;

  const _PromocionCard({required this.promocion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final comercio = promocion['comercio'] as Map<String, dynamic>?;
    final fotoUrl = promocion['foto_url'] as String?;
    final descuento = promocion['valor'];
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen con badge de descuento
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: fotoUrl != null && fotoUrl.isNotEmpty
                      ? Image.network(
                          fotoUrl,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 200,
                              color: AppTheme.cardBackground,
                              child: const Icon(
                                Icons.image_outlined,
                                size: 60,
                                color: AppTheme.textSecondary,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: double.infinity,
                          height: 200,
                          color: AppTheme.cardBackground,
                          child: const Icon(
                            Icons.image_outlined,
                            size: 60,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFEA963A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '-$descuento%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'OFF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Información
            Padding(
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 4),
                  if (comercio != null)
                    Text(
                      comercio['nombre'] ?? 'Salón',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (promocion['precio_original'] != null)
                        Text(
                          '€${promocion['precio_original']}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        '€${promocion['precio_con_descuento'] ?? '0.00'}',
                        style: const TextStyle(
                          color: AppTheme.primaryOrange,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
