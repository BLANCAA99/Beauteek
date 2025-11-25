import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'edit_profile_page.dart';
import 'api_constants.dart';

class ProfileInfoPage extends StatelessWidget {
  final String? uid;
  const ProfileInfoPage({Key? key, this.uid}) : super(key: key);

  // Colores Beauteek
  static const Color _backgroundColor = Color(0xFF050505);
  static const Color _cardColor = Color(0xFF141414);
  static const Color _rowColor = Color(0xFF1E1E1E);
  static const Color _primaryOrange = Color(0xFFEA963A);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB3ACA5);

  // ---------------------------------------------------------------------------
  // 🔥 Cargar datos desde API o Firestore, versión limpia
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> _loadUserData() async {
    final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUid == null) throw Exception('Usuario no autenticado');

    final Map<String, dynamic> userData = {};

    // 1. Intentar cargar desde tu API
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final idToken = await user.getIdToken();
        final url = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');

        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final apiData = json.decode(response.body) as Map<String, dynamic>;

          userData['fullName'] = apiData['nombre_completo'] ?? '';
          userData['phone'] = apiData['telefono'] ?? '';
          userData['photoURL'] = apiData['foto_url'] ?? '';
          userData['direccion'] = apiData['direccion'] ?? '';

          final nacimientoApi = apiData['fecha_nacimiento'];
          userData['dob'] = nacimientoApi is String ? nacimientoApi : '';

          userData['gender'] = apiData['genero'] ?? '';
          userData['country'] = apiData['pais'] ?? '';
          userData['email'] = apiData['email'] ?? user.email ?? '-';
          userData['rol'] = apiData['rol'] ?? '';

          return userData;
        }
      }
    } catch (e) {
      print("🔥 Error API: $e");
    }

    // 2. Fallback Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(resolvedUid)
        .get();

    if (doc.exists && doc.data() != null) {
      final fs = doc.data()!;

      userData['fullName'] = fs['nombre_completo'] ?? '';
      userData['phone'] = fs['telefono'] ?? '';
      userData['photoURL'] = fs['foto_url'] ?? '';
      userData['direccion'] = fs['direccion'] ?? '';
      userData['dob'] = fs['fecha_nacimiento'] ?? '';
      userData['gender'] = fs['genero'] ?? '';
      userData['country'] = fs['pais'] ?? '';
      userData['rol'] = fs['rol'] ?? '';
    }

    // 3. Email desde FirebaseAuth
    final authUser = FirebaseAuth.instance.currentUser;
    userData['email'] = authUser?.email ?? userData['email'] ?? '-';

    // Si no hay nombre completo, usar displayName
    if ((userData['fullName'] == null ||
        (userData['fullName'] as String).isEmpty)) {
      userData['fullName'] = authUser?.displayName ?? 'Usuario';
    }

    return userData;
  }

  // ---------------------------------------------------------------------------
  // 🔹 Widget fila individual
  // ---------------------------------------------------------------------------
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _rowColor,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(24))
            : BorderRadius.zero,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _textSecondary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : "-",
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🔥 UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: const BackButton(color: _textPrimary),
        title: const Text(
          "Mi perfil",
          style: TextStyle(
              color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: _primaryOrange));
          }

          if (snapshot.hasError) {
            return const Center(
                child: Text("Error al cargar datos",
                    style: TextStyle(color: Colors.redAccent)));
          }

          final data = snapshot.data ?? {};

          final fullName = (data['fullName'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          final dob = (data['dob'] ?? '').toString();
          final gender = (data['gender'] ?? '').toString();
          final country = (data['country'] ?? '').toString();
          final avatarUrl = (data['photoURL'] ?? '').toString();
          final rol = (data['rol'] ?? 'cliente').toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              children: [
                // -----------------------------------------------------------------
                // 🔥 Tarjeta superior: Avatar + Nombre + Editar
                // -----------------------------------------------------------------
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(26)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage:
                            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty
                            ? const Icon(Icons.person,
                                size: 40, color: _textSecondary)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          fullName,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditProfilePage(userData: data),
                            ),
                          );
                        },
                        child: const Text(
                          "Editar",
                          style: TextStyle(
                              color: _primaryOrange,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // -----------------------------------------------------------------
                // 🔹 Datos del usuario
                // -----------------------------------------------------------------
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(26)),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),

                      _infoRow(
                        icon: Icons.person_outline,
                        label: "Nombre completo",
                        value: fullName,
                      ),

                      const Divider(
                        height: 1,
                        color: Colors.black54,
                        indent: 54,
                        endIndent: 18,
                      ),

                      _infoRow(
                        icon: Icons.phone_outlined,
                        label: "Número de teléfono",
                        value: phone,
                      ),

                      const Divider(
                        height: 1,
                        color: Colors.black54,
                        indent: 54,
                        endIndent: 18,
                      ),

                      _infoRow(
                        icon: Icons.email_outlined,
                        label: "Email",
                        value: email,
                      ),

                      if (rol == "cliente") ...[
                        const Divider(
                          height: 1,
                          color: Colors.black54,
                          indent: 54,
                          endIndent: 18,
                        ),
                        _infoRow(
                          icon: Icons.calendar_today_outlined,
                          label: "Fecha de nacimiento",
                          value: dob,
                        ),
                        const Divider(
                          height: 1,
                          color: Colors.black54,
                          indent: 54,
                          endIndent: 18,
                        ),
                        _infoRow(
                          icon: Icons.transgender_outlined,
                          label: "Género",
                          value: gender,
                        ),
                        const Divider(
                          height: 1,
                          color: Colors.black54,
                          indent: 54,
                          endIndent: 18,
                        ),
                        _infoRow(
                          icon: Icons.public_outlined,
                          label: "País",
                          value: country,
                          isLast: true,
                        ),
                      ] else
                        _infoRow(
                          icon: Icons.email_outlined,
                          label: "Email",
                          value: email,
                          isLast: true,
                        ),

                      const SizedBox(height: 6),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}