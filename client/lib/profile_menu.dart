import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';
import 'profile_info.dart';
import 'inicio.dart';
import 'salon_registration_steps_page.dart';
import 'api_constants.dart';
import 'edit_services_page.dart';
import 'reportes_salon_page.dart';
import 'search_page.dart';
import 'estadisticas_salon_page.dart';
import 'mis_resenas_page.dart';
import 'favoritos_page.dart';
import 'theme/app_theme.dart';
import 'privacidad_seguridad_page.dart';
import 'configuracion_salon_page.dart';
import 'centro_ayuda_page.dart';
import 'notificaciones_page.dart';
import 'galeria_salon_page.dart';
import 'promociones_page.dart';
import 'gestionar_promociones_page.dart';
import 'reportes_cliente_page.dart';

class ProfileMenuPage extends StatefulWidget {
  final String? uid;
  const ProfileMenuPage({Key? key, this.uid}) : super(key: key);

  @override
  State<ProfileMenuPage> createState() => _ProfileMenuPageState();
}

class _ProfileMenuPageState extends State<ProfileMenuPage> {
  static const Color _fondoIcono = Color(0xFF3A3A3C);

  String? _userRole;
  Map<String, dynamic>? _userHeader;
  bool _isLoading = true;
  String? _resolvedUid;

  @override
  void initState() {
    super.initState();
    _resolvedUid = widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
    _loadUserData();
  }

  // ✅ Cargar datos del usuario UNA SOLA VEZ al inicio
  Future<void> _loadUserData() async {
    if (_resolvedUid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final idToken = await authUser.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/users/uid/$_resolvedUid');

      final resp = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final raw = json.decode(resp.body) as Map<String, dynamic>;

        final nombreCompleto =
            (raw['nombre_completo'] ?? raw['fullName'] ?? '').toString().trim();
        final first = (raw['firstName'] ?? raw['nombre'] ?? '').toString();
        final last = (raw['lastName'] ?? raw['apellido'] ?? '').toString();
        final displayName =
            nombreCompleto.isNotEmpty ? nombreCompleto : ('$first $last').trim();
        final photoUrl =
            (raw['foto_url'] ?? raw['photoURL'] ?? raw['photo'] ?? '').toString();

        setState(() {
          _userRole = raw['rol'] as String? ?? 'cliente';
          _userHeader = {
            'displayName': displayName.isNotEmpty ? displayName : 'Usuario',
            'photoUrl': photoUrl,
            'rol': _userRole,
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _userRole = 'cliente';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error cargando datos del usuario: $e');
      setState(() {
        _userRole = 'cliente';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryOrange,
          ),
        ),
      );
    }

    final displayName = _userHeader?['displayName'] ?? 'Usuario';
    final photoUrl = _userHeader?['photoUrl'];
    final subtitle =
        _userRole == 'salon' ? 'Perfil del salón' : 'Perfil personal';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    // Header con back + avatar + nombre
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: AppTheme.cardBackground,
                                backgroundImage:
                                    (photoUrl != null && photoUrl.isNotEmpty)
                                        ? NetworkImage(photoUrl)
                                        : null,
                                child: (photoUrl == null || photoUrl.isEmpty)
                                    ? const Icon(
                                        Icons.person,
                                        color: AppTheme.textSecondary,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: AppTheme.heading1.copyWith(fontSize: 28),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 🔸 Menú dinámico por rol (ahora sin FutureBuilder)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: _buildMenuOptions(context),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 🔻 Cerrar sesión (sin cambios)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: GestureDetector(
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.logout,
                              color: AppTheme.errorRed,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                color: AppTheme.errorRed,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // 🔻 BottomNavigationBar dinámico por rol (ahora sin FutureBuilder)
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  // ✅ Construir opciones de menú basado en rol (ya cargado)
  List<Widget> _buildMenuOptions(BuildContext context) {
    final List<Widget> opciones = [];

    // Perfil (todos)
    opciones.add(
      _menuTileConIcono(
        context,
        Icons.person_outline,
        'Perfil',
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileInfoPage(uid: _resolvedUid),
            ),
          );
        },
      ),
    );

    if (_userRole == 'salon') {
      // --- Opciones para salón ---
      opciones.add(
        _menuTileConIcono(
          context,
          Icons.settings_outlined,
          'Configurar servicios y horarios',
          () async {
            try {
              final authUser = FirebaseAuth.instance.currentUser;
              if (authUser == null) return;

              final idToken = await authUser.getIdToken();
              final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
              final comerciosResponse = await http.get(
                comerciosUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
              );

              if (comerciosResponse.statusCode == 200) {
                final List<dynamic> comercios =
                    json.decode(comerciosResponse.body);
                final miComercio = comercios.firstWhere(
                  (c) => c['uid_negocio'] == authUser.uid,
                  orElse: () => null,
                );

                if (miComercio != null && context.mounted) {
                  final comercioId = miComercio['id'];

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditServicesPage(comercioId: comercioId),
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se encontró tu comercio'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      );

      opciones.add(
        _menuTileConIcono(
          context,
          Icons.analytics_outlined,
          'Reportes detallados',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReportesSalonPage(),
              ),
            );
          },
        ),
      );

      // 🔹 NUEVAS OPCIONES PARA SALÓN
      opciones.add(
        _menuTileConIcono(
          context,
          Icons.photo_library_outlined,
          'Galería del salón',
          () async {
            try {
              final authUser = FirebaseAuth.instance.currentUser;
              if (authUser == null) return;

              final idToken = await authUser.getIdToken();
              final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
              final comerciosResponse = await http.get(
                comerciosUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
              );

              if (comerciosResponse.statusCode == 200) {
                final List<dynamic> comercios =
                    json.decode(comerciosResponse.body);
                final miComercio = comercios.firstWhere(
                  (c) => c['uid_negocio'] == authUser.uid,
                  orElse: () => null,
                );

                if (miComercio != null && context.mounted) {
                  final comercioId = miComercio['id'];

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GaleriaSalonPage(comercioId: comercioId),
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se encontró tu comercio'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      );

      opciones.add(
        _menuTileConIcono(
          context,
          Icons.notifications_none_outlined,
          'Notificaciones',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificacionesPage(),
              ),
            );
          },
        ),
      );

      opciones.add(
        _menuTileConIcono(
          context,
          Icons.help_outline,
          'Centro de ayuda',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CentroAyudaPage(),
              ),
            );
          },
        ),
      );

      opciones.add(
        _menuTileConIcono(
          context,
          Icons.tune_rounded,
          'Configuración del salón',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ConfiguracionSalonPage(),
              ),
            );
          },
        ),
      );

      opciones.add(
        _menuTileConIcono(
          context,
          Icons.verified_user_outlined,
          'Privacidad y seguridad',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PrivacidadSeguridadPage(),
              ),
            );
          },
        ),
      );

      opciones.add(
        _menuTileConIcono(
          context,
          Icons.local_offer_outlined,
          'Gestionar Promociones',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GestionarPromocionesPage(),
              ),
            );
          },
        ),
      );
    } else {
      // --- Opciones para cliente ---
      opciones.add(
        _menuTileConIcono(
          context,
          Icons.analytics_outlined,
          'Mis Reportes',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReportesClientePage(),
              ),
            );
          },
        ),
      );
      opciones.add(
        _menuTileConIcono(
          context,
          Icons.favorite_border,
          'Favoritos',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FavoritosPage(),
              ),
            );
          },
        ),
      );
      opciones.add(
        _menuTileConIcono(
          context,
          Icons.rate_review_outlined,
          'Mis reseñas',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MisResenasPage(),
              ),
            );
          },
        ),
      );
      opciones.add(
        _menuTileConIcono(
          context,
          Icons.store_outlined,
          'Registrar mi salón de belleza',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SalonRegistrationStepsPage(),
              ),
            );
          },
        ),
      );
    }

    return opciones;
  }

  // ✅ Construir BottomNavigationBar basado en rol (ya cargado)
  Widget _buildBottomNavBar(BuildContext context) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        label: 'Inicio',
      ),
      if (_userRole == 'salon')
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          label: 'Estadísticas',
        )
      else
        const BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Buscar',
        ),
      if (_userRole == 'salon')
        const BottomNavigationBarItem(
          icon: Icon(Icons.local_offer_outlined),
          label: 'Mis Promociones',
        )
      else
        const BottomNavigationBarItem(
          icon: Icon(Icons.local_offer_outlined),
          label: 'Promociones',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month_outlined),
        label: 'Calendario',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Perfil',
      ),
    ];

    return BottomNavigationBar(
      currentIndex: 4, // Perfil seleccionado
      items: items,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.cardBackground,
      selectedItemColor: AppTheme.primaryOrange,
      unselectedItemColor: AppTheme.textSecondary,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      elevation: 8,
      onTap: (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => InicioPage()),
            );
            break;
          case 1:
            if (_userRole == 'salon') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EstadisticasSalonPage(),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchPage(
                    mode: 'search',
                    userId: widget.uid,
                    userCountry: 'Honduras',
                  ),
                ),
              );
            }
            break;
          case 2:
            if (_userRole == 'salon') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GestionarPromocionesPage(),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PromocionesPage(),
                ),
              );
            }
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _PlaceholderPage(title: 'Calendario'),
              ),
            );
            break;
          case 4:
            // Ya estás en Perfil
            break;
        }
      },
    );
  }

  // Tarjeta con icono personalizado
  Widget _menuTileConIcono(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: AppTheme.elevatedCardDecoration(borderRadius: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _fondoIcono,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryOrange,
                  size: 26,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title - placeholder')),
    );
  }
}