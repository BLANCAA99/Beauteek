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

        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        print('📬 [API Response] StatusCode: ${response.statusCode}');
        print('📦 [API Response] Body: ${response.body}');

        if (response.statusCode == 200) {
          final apiData = json.decode(response.body) as Map<String, dynamic>;
          
          // Mapear campos de la API a los que usa la UI
          final nombreCompleto = (apiData['nombre_completo'] ?? '') as String;
          if (nombreCompleto.isNotEmpty) {
            final parts = nombreCompleto.split(' ');
            userData['firstName'] = parts.first;
            userData['lastName'] = parts.length > 1 ? parts.sublist(1).join(' ') : '';
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
    final doc = await FirebaseFirestore.instance.collection('users').doc(resolvedUid).get();

    if (doc.exists && doc.data() != null) {
      final firestoreData = doc.data()!;
      
      final nombreCompleto = (firestoreData['nombre_completo'] ?? '') as String;
      if (nombreCompleto.isNotEmpty) {
        final parts = nombreCompleto.split(' ');
        userData['firstName'] = parts.first;
        userData['lastName'] = parts.length > 1 ? parts.sublist(1).join(' ') : '';
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

    if ((userData['firstName'] == null || (userData['firstName'] as String).isEmpty) && user?.displayName != null) {
        final parts = user!.displayName!.split(' ');
        userData['firstName'] = parts.first;
        userData['lastName'] = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    return userData;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(value.isNotEmpty ? value : '-', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _addressTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
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
    const accentColor = Color(0xFF6A4AE0);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
      ),
      body: SizedBox.expand( 
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar datos'));
            }

            final data = snapshot.data ?? {};
            final firstName = (data['firstName'] ?? data['nombre'] ?? '').toString();
            final lastName  = (data['lastName']  ?? data['apellido'] ?? '').toString();
            final phone     = (data['phone']     ?? data['phoneNumber'] ?? data['telefono'] ?? '').toString();
            final email     = (data['email']     ?? '').toString();
            final dob       = (data['dob']       ?? data['fechaNacimiento'] ?? '').toString();
            final gender    = (data['gender']    ?? data['genero'] ?? '').toString();
            final avatarUrl = (data['photoURL']  ?? '').toString();
            final rol       = (data['rol']       ?? 'cliente').toString(); // ✅ OBTENER ROL

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page title
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text('Mi perfil', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  ),

                  // Top white card with avatar and big name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Column(
                          children: [
                            // Edit button aligned top-right (visually placed above avatar)
                            Row(
                              children: [
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    // Navega a la página de edición y pasa los datos actuales
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => EditProfilePage(userData: data),
                                      ),
                                    );
                                  },
                                  child: const Text('Editar', style: TextStyle(fontWeight: FontWeight.w600)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: accentColor,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(40, 20),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Avatar with small edit icon
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 56,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) as ImageProvider : null,
                                  child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 56, color: Colors.white) : null,
                                ),
                                Positioned(
                                  right: MediaQuery.of(context).size.width * 0.5 - 56 + 12,
                                  bottom: 8,
                                  child: GestureDetector(
                                    onTap: () {},
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(Icons.edit, size: 18, color: Colors.black54),
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${firstName.trim()} ${lastName.trim()}'.trim(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Info card (white, subtle separators)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          _infoRow('Nombre', firstName.isNotEmpty ? firstName : '-'),
                          Divider(height: 1, color: Colors.grey.shade200),
                          _infoRow('Apellido', lastName.isNotEmpty ? lastName : '-'),
                          Divider(height: 1, color: Colors.grey.shade200),
                          _infoRow('Número de teléfono móvil', phone.isNotEmpty ? phone : '-'),
                          Divider(height: 1, color: Colors.grey.shade200),
                          _infoRow('Email', email.isNotEmpty ? email : '-'),
                          // ✅ CAMBIO: Solo mostrar fecha de nacimiento y género si es cliente
                          if (rol == 'cliente') ...[
                            Divider(height: 1, color: Colors.grey.shade200),
                            _infoRow('Fecha de nacimiento', dob.isNotEmpty ? dob : '-'),
                            Divider(height: 1, color: Colors.grey.shade200),
                            _infoRow('Género', gender.isNotEmpty ? gender : '-'),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // "Mis direcciones" section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mis direcciones', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _addressTile(context, Icons.home_filled, 'Casa', 'Añadir la dirección de un domicilio', () {
                          // TODO: Implementar navegación/edición de direcciones
                        }),
                        _addressTile(context, Icons.work_outline, 'Trabajo', 'Añadir una dirección de trabajo', () {}),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 140,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.add, color: Colors.black87),
                            label: const Text('Añadir', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
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