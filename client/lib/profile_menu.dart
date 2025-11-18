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

class ProfileMenuPage extends StatelessWidget {
  final String? uid;
  const ProfileMenuPage({Key? key, this.uid}) : super(key: key);

  static const Color _fondoIcono = Color(0xFF3A3A3C);

  // ✅ Obtener rol del usuario
  Future<String?> _fetchUserRole(String uid) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return null;

    final idToken = await authUser.getIdToken();
    final url = Uri.parse('$apiBaseUrl/api/users/uid/$uid');

    final resp = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (resp.statusCode != 200) return null;

    final raw = json.decode(resp.body) as Map<String, dynamic>;
    return raw['rol'] as String?;
  }

  // GET /users/uid/:uid  (getUserById)
  Future<Map<String, dynamic>?> _fetchUserHeader(String uid) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return null;

    final idToken = await authUser.getIdToken();
    final url = Uri.parse('$apiBaseUrl/api/users/uid/$uid');

    final resp = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (resp.statusCode != 200) return null;

    final raw = json.decode(resp.body) as Map<String, dynamic>;
    final nombreCompleto =
        (raw['nombre_completo'] ?? raw['fullName'] ?? '').toString().trim();

    final first = (raw['firstName'] ?? raw['nombre'] ?? '').toString();
    final last = (raw['lastName'] ?? raw['apellido'] ?? '').toString();

    final displayName =
        nombreCompleto.isNotEmpty ? nombreCompleto : ('$first $last').trim();

    final photoUrl =
        (raw['foto_url'] ?? raw['photoURL'] ?? raw['photo'] ?? '').toString();

    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'rol': raw['rol'] as String?,
    };
  }

  // (ya no la usamos, pero la dejo por si luego quieres algo más simple)
  Widget _menuTile(
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
                child: const Icon(
                  Icons.person_outline,
                  color: AppTheme.primaryOrange,
                  size: 0,
                ),
              ),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;

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
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: resolvedUid != null
                            ? _fetchUserHeader(resolvedUid)
                            : Future.value(null),
                        builder: (context, snapshot) {
                          String displayName = 'Usuario';
                          String? photoUrl;
                          String subtitle = 'Perfil personal';

                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.hasData) {
                            final data = snapshot.data!;
                            displayName = data['displayName'] ?? 'Usuario';
                            photoUrl = data['photoUrl'];
                            final rol = data['rol'] as String?;
                            if (rol == 'salon') subtitle = 'Perfil del salón';
                          } else if (snapshot.connectionState ==
                              ConnectionState.done) {
                            final authUser = FirebaseAuth.instance.currentUser;
                            displayName = authUser?.displayName ?? 'Usuario';
                            photoUrl = authUser?.photoURL;
                          }

                          if (displayName.isEmpty) {
                            displayName = 'Usuario';
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
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
                                    child: (photoUrl == null ||
                                            photoUrl.isEmpty)
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: AppTheme.heading1
                                          .copyWith(fontSize: 28),
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
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 🔸 Menú dinámico por rol
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FutureBuilder<String?>(
                        future: resolvedUid != null
                            ? _fetchUserRole(resolvedUid)
                            : Future.value(null),
                        builder: (context, snapshot) {
                          final rol = snapshot.data ?? 'cliente';
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
                                    builder: (_) =>
                                        ProfileInfoPage(uid: resolvedUid),
                                  ),
                                );
                              },
                            ),
                          );

                          if (rol == 'salon') {
                            // --- Opciones para salón ---
                            opciones.add(
                              _menuTileConIcono(
                                context,
                                Icons.settings_outlined,
                                'Configurar servicios y horarios',
                                () async {
                                  try {
                                    final authUser =
                                        FirebaseAuth.instance.currentUser;
                                    if (authUser == null) return;

                                    final idToken =
                                        await authUser.getIdToken();
                                    final comerciosUrl =
                                        Uri.parse('$apiBaseUrl/comercios');
                                    final comerciosResponse = await http.get(
                                      comerciosUrl,
                                      headers: {
                                        'Content-Type': 'application/json',
                                        'Authorization': 'Bearer $idToken',
                                      },
                                    );

                                    if (comerciosResponse.statusCode == 200) {
                                      final List<dynamic> comercios =
                                          json.decode(
                                              comerciosResponse.body);
                                      final miComercio = comercios.firstWhere(
                                        (c) =>
                                            c['uid_negocio'] == authUser.uid,
                                        orElse: () => null,
                                      );

                                      if (miComercio != null &&
                                          context.mounted) {
                                        final comercioId = miComercio['id'];

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditServicesPage(
                                                comercioId: comercioId),
                                          ),
                                        );
                                      } else if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'No se encontró tu comercio'),
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
                                      builder: (_) =>
                                          const ReportesSalonPage(),
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
                                      builder: (_) =>
                                          const SalonRegistrationStepsPage(),
                                    ),
                                  );
                                },
                              ),
                            );
                          }

                          return Column(children: opciones);
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 🔻 Cerrar sesión
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

      // 🔻 BottomNavigationBar dinámico por rol
      bottomNavigationBar: FutureBuilder<String?>(
        future: resolvedUid != null
            ? _fetchUserRole(resolvedUid)
            : Future.value('cliente'),
        builder: (context, snapshot) {
          final rol = snapshot.data ?? 'cliente';

          final items = <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Inicio',
            ),
            if (rol == 'salon')
              const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                label: 'Estadísticas',
              )
            else
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Buscar',
              ),
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

            // 👇 Forzamos el mismo estilo oscuro del resto de la app
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
                  if (rol == 'salon') {
                    // Estadísticas para salón
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EstadisticasSalonPage(),
                      ),
                    );
                  } else {
                    // Buscar para cliente
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchPage(
                          mode: 'search',
                          userId: uid,
                          userCountry: 'Honduras',
                        ),
                      ),
                    );
                  }
                  break;
                case 2:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const _PlaceholderPage(title: 'Promociones'),
                    ),
                  );
                  break;
                case 3:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const _PlaceholderPage(title: 'Calendario'),
                    ),
                  );
                  break;
                case 4:
                  // Ya estás en Perfil
                  break;
              }
            },
          );
        },
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