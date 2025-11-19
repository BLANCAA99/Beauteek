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

  // Colores de tema oscuro Beauteek
  static const Color _backgroundColor = Color(0xFF050505);
  static const Color _cardColor = Color(0xFF141414);
  static const Color _rowColor = Color(0xFF1E1E1E);
  static const Color _primaryOrange = Color(0xFFEA963A);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFB3ACA5);

  Future<Map<String, dynamic>> _loadUserData() async {
    final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUid == null) throw Exception('Usuario no autenticado');

    final Map<String, dynamic> userData = {};

    // 1. Intentar cargar datos desde tu API
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken();
        final url = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');

        print('[API Call] GET: $url');

        final response = await http
            .get(
          url,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        )
            .timeout(const Duration(seconds: 10));

        print('📬 [API Response] StatusCode: ${response.statusCode}');
        print('📦 [API Response] Body: ${response.body}');

        if (response.statusCode == 200) {
          final apiData =
              json.decode(response.body) as Map<String, dynamic>;

          // Mapear campos de la API a los que usa la UI
          final nombreCompleto =
              (apiData['nombre_completo'] ?? '') as String;
          if (nombreCompleto.isNotEmpty) {
            final parts = nombreCompleto.split(' ');
            userData['firstName'] = parts.first;
            userData['lastName'] = parts.length > 1
                ? parts.sublist(1).join(' ')
                : '';
          }

          userData['phone'] = apiData['telefono'] ?? '';
          userData['photoURL'] = apiData['foto_url'] ?? '';
          userData['direccion'] = apiData['direccion'] ?? '';
          userData['dob'] = apiData['fecha_creacion'] ?? '';
          userData['gender'] = apiData['genero'] ?? '';
          userData['email'] = apiData['email'] ?? user.email ?? '-';
          userData['rol'] = apiData['rol'] ?? ''; // ✅ AGREGAR ROL

          return userData;
        }
      }
    } catch (e) {
      print('🔥 [API Error] Exception: $e');
    }

    // 2. Fallback: Cargar datos desde la colección 'users' en Firestore.
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(resolvedUid)
        .get();

    if (doc.exists && doc.data() != null) {
      final firestoreData = doc.data()!;

      final nombreCompleto =
          (firestoreData['nombre_completo'] ?? '') as String;
      if (nombreCompleto.isNotEmpty) {
        final parts = nombreCompleto.split(' ');
        userData['firstName'] = parts.first;
        userData['lastName'] = parts.length > 1
            ? parts.sublist(1).join(' ')
            : '';
      }

      userData['phone'] = firestoreData['telefono'] ?? '';
      userData['photoURL'] = firestoreData['foto_url'] ?? '';
      userData['direccion'] = firestoreData['direccion'] ?? '';
      userData['dob'] = firestoreData['fecha_creacion'] ?? '';
      userData['gender'] = firestoreData['genero'] ?? '';
      userData['rol'] = firestoreData['rol'] ?? ''; // ✅ AGREGAR ROL
    }

    // 3. Asegurar que el email de FirebaseAuth se use siempre.
    final user = FirebaseAuth.instance.currentUser;
    userData['email'] = user?.email ?? userData['email'] ?? '-';

    if ((userData['firstName'] == null ||
            (userData['firstName'] as String).isEmpty) &&
        user?.displayName != null) {
      final parts = user!.displayName!.split(' ');
      userData['firstName'] = parts.first;
      userData['lastName'] =
          parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    return userData;
  }

  // Fila de info con icono, label gris y valor blanco
  Widget _infoRow(
      {required IconData icon,
      required String label,
      required String value,
      bool isLast = false}) {
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
                Text(
                  label,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // (Sigue existiendo aunque por ahora no se use, para no tocar nada de lógica)
  Widget _addressTile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: const BackButton(color: _textPrimary),
        title: const Text(
          'Mi perfil',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SizedBox.expand(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _primaryOrange,
                ),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Error al cargar datos',
                  style: TextStyle(color: Colors.redAccent),
                ),
              );
            }

            final data = snapshot.data ?? {};
            final firstName =
                (data['firstName'] ?? data['nombre'] ?? '').toString();
            final lastName =
                (data['lastName'] ?? data['apellido'] ?? '').toString();
            final phone = (data['phone'] ??
                    data['phoneNumber'] ??
                    data['telefono'] ??
                    '')
                .toString();
            final email = (data['email'] ?? '').toString();
            final dob =
                (data['dob'] ?? data['fechaNacimiento'] ?? '').toString();
            final gender =
                (data['gender'] ?? data['genero'] ?? '').toString();
            final avatarUrl = (data['photoURL'] ?? '').toString();
            final rol = (data['rol'] ?? 'cliente').toString();

            final fullName =
                '${firstName.trim()} ${lastName.trim()}'.trim();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  // Tarjeta superior: avatar + nombre + Editar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.grey.shade800,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: _textSecondary,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            fullName.isNotEmpty ? fullName : 'Usuario',
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
                                builder: (_) =>
                                    EditProfilePage(userData: data),
                              ),
                            );
                          },
                          child: const Text(
                            'Editar',
                            style: TextStyle(
                              color: _primaryOrange,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Tarjeta de información (filas oscuras)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        _infoRow(
                          icon: Icons.person_outline,
                          label: 'Nombre',
                          value: firstName,
                        ),
                        const Divider(
                          height: 1,
                          color: Colors.black54,
                          indent: 54,
                          endIndent: 18,
                        ),
                        _infoRow(
                          icon: Icons.person_outline,
                          label: 'Apellido',
                          value: lastName,
                        ),
                        const Divider(
                          height: 1,
                          color: Colors.black54,
                          indent: 54,
                          endIndent: 18,
                        ),
                        _infoRow(
                          icon: Icons.phone_outlined,
                          label: 'Número de teléfono móvil',
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
                          label: 'Email',
                          value: email,
                        ),
                        if (rol == 'cliente') ...[
                          const Divider(
                            height: 1,
                            color: Colors.black54,
                            indent: 54,
                            endIndent: 18,
                          ),
                          _infoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Fecha de nacimiento',
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
                            label: 'Género',
                            value: gender,
                            isLast: true,
                          ),
                        ] else
                          // Para salón, la última fila es email (redondear abajo)
                          _infoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: email,
                            isLast: true,
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}