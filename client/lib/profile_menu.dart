import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

import 'profile_info.dart';
import 'inicio.dart';

class ProfileMenuPage extends StatelessWidget {
  final String? uid;
  const ProfileMenuPage({Key? key, this.uid}) : super(key: key);

  // GET /users/:uid  (getUserById)
  Future<Map<String, dynamic>?> _fetchUserHeader(String uid) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return null;

    final idToken = await authUser.getIdToken();
    // CORRECCIÓN: Construir la URL completa directamente para consistencia.
    final url = Uri.parse('http://10.0.2.2:5001/beauteek-b595e/us-central1/api/api/users/$uid');

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
    final last  = (raw['lastName']  ?? raw['apellido'] ?? '').toString();

    final displayName =
        nombreCompleto.isNotEmpty ? nombreCompleto : ('$first $last').trim();

    final photoUrl =
        (raw['foto_url'] ?? raw['photoURL'] ?? raw['photo'] ?? '').toString();

    return {'displayName': displayName, 'photoUrl': photoUrl};
  }

  Widget _menuTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.black87, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(''),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header: carga nombre/foto desde la API
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FutureBuilder<Map<String, dynamic>?>(
                future: resolvedUid != null ? _fetchUserHeader(resolvedUid) : Future.value(null),
                builder: (context, snapshot) {
                  String displayName = 'Usuario'; // Valor por defecto
                  String subtitle = 'Perfil personal';
                  String? photoUrl;

                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                    final data = snapshot.data!;
                    displayName = data['displayName'] ?? 'Usuario';
                    photoUrl = data['photoUrl'];
                  } else if (snapshot.connectionState == ConnectionState.done) {
                    // Fallback si la API falla o no devuelve datos
                    final authUser = FirebaseAuth.instance.currentUser;
                    displayName = authUser?.displayName ?? 'Usuario';
                    photoUrl = authUser?.photoURL;
                  }

                  // Si después de todo, el nombre está vacío, muestra 'Usuario'.
                  if (displayName.isEmpty) {
                    displayName = 'Usuario';
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            const Text('Perfil personal', style: TextStyle(fontSize: 15, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                        child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: Colors.white) : null,
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Menú principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 6))],
                ),
                child: Column(
                  children: [
                    _menuTile(context, Icons.person_outline, 'Perfil', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileInfoPage(uid: resolvedUid)));
                    }),
                    const Divider(height: 1),
                    _menuTile(context, Icons.favorite_border, 'Favoritos', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const _PlaceholderPage(title: 'Favoritos')));
                    }),
                    const Divider(height: 1),
                    _menuTile(context, Icons.feed_outlined, 'Formularios', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const _PlaceholderPage(title: 'Formularios')));
                    }),
                    const Divider(height: 1),
                    _menuTile(context, Icons.inventory_2_outlined, 'Pedidos de productos', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const _PlaceholderPage(title: 'Pedidos de productos')));
                    }),
                    const Divider(height: 1),
                    _menuTile(context, Icons.settings_outlined, 'Ajustes', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const _PlaceholderPage(title: 'Ajustes')));
                    }),
                    const Divider(height: 1),
                    // Opción para Cerrar Sesión
                    _menuTile(context, Icons.logout, 'Cerrar sesión', () async {
                      await FirebaseAuth.instance.signOut();
                      // Navega a la pantalla de login y elimina todas las rutas anteriores.
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()), // Asumiendo que tu login se llama LoginScreen
                        (Route<dynamic> route) => false,
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF0F2F4))),
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => InicioPage())),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home, color: Color(0xFF111418), size: 24),
                  SizedBox(height: 4),
                  Text('Inicio', style: TextStyle(color: Color(0xFF111418), fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _PlaceholderPage(title: 'Buscar'))),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, color: Color(0xFF637588), size: 24),
                  SizedBox(height: 4),
                  Text('Buscar', style: TextStyle(color: Color(0xFF637588), fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _PlaceholderPage(title: 'Favoritos'))),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, color: Color(0xFF637588), size: 24),
                  SizedBox(height: 4),
                  Text('Favoritos', style: TextStyle(color: Color(0xFF637588), fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline, color: Color(0xFF111418), size: 24),
                SizedBox(height: 4),
                Text('Perfil', style: TextStyle(color: Color(0xFF111418), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
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
      appBar: AppBar(title: Text(title), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black87), elevation: 0),
      body: Center(child: Text('$title - placeholder')),
    );
  }
}