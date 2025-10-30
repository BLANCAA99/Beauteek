import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_menu.dart'; // agregado import para navegar al menú de perfil

class InicioPage extends StatelessWidget {
  final salones = [
    {
      'nombre': "Salón de belleza 'Glamour'",
      'img':
          "https://lh3.googleusercontent.com/aida-public/AB6AXuChxkXpPVKBgo_GuiB7C6E3kHU3ywvIZTckibg7ayW6wFVxRPVj68kxesF1ifXiMPSvzAMBSw4rZ80KvIvUkCCDaDausLNE0wJ5iqvdsyntyZ-s0516ih-Fz2xrYIVigHgp5qFIJGORrfdgZR55dGlhrTP8qBcCNCCth1pLubWEg9hFw6VZHCCa42a3YXxvNibFyG4M3HQytmfsOF13l_1_RLvN2yaw4M9zBKcbGwJ1fNY3-OA4lTl_n-9izdzXnv05B_sIDhxTPFM",
      'rating': "4.8",
      'reviews': "123"
    },
    {
      'nombre': "Salón de belleza 'Chic'",
      'img':
          "https://lh3.googleusercontent.com/aida-public/AB6AXuAwDbWKgsLvNq8qUcNftXj07fRHH9Qgl2kUwbkTX2XefpWdsp_z1lEwFV2hvCFLmT5ixdloV0ZMWNzlZm2hBlaQOl_0zC1O9GRMAc3RtwbujVnmln75G3EJPqdi1BJ_6lntdMC92SOLZ6BqIRS55bg1sb5weZiuCR6ZlzLiSyHPmfEH2DHasqw6m0zZAp2XVZbkKfbWzBZbo5xX0flAxU_MFaTscCUFlNHkmmS6ihylux-aTpufky3vVXoKI6tnVoJ_xYClWzYU394",
      'rating': "4.9",
      'reviews': "234"
    },
    {
      'nombre': "Salón de belleza 'Elegancia'",
      'img':
          "https://lh3.googleusercontent.com/aida-public/AB6AXuBQanvQq4MAAk0O1ox9Q92K75vTWJupAqm3haKLSbKpOCi04jA8ggLCNXWv0tCfsSl4hvRtWY8mbYW7lu4UcoXFt4qdYr_LK1VkFRXCSvMCCx_zwNXPkjSInoxKXVHyq7dUdIP-9ocrDwGOkLiv2Inwka5ZdmYrwgPusTXz7urT8n4AWEc2yxK0ck1DYIoB9R23WkuRwChDQMmsOh2rbuiAJemuz42aO0UxU6uR59074uj_DPi9jBsYkBAKTP1AxVLFvStdmvN1_7g",
      'rating': "4.7",
      'reviews': "345"
    },
  ];

  final categorias = [
    "Uñas",
    "Cabello",
    "Maquillaje",
    "Facial",
    "Masajes",
    "Depilación"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'Beauteek',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Color(0xFF111418),
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.menu, color: Color(0xFF111418), size: 28),
                ],
              ),
            ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFFF0F2F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Icon(Icons.search, color: Color(0xFF637588)),
                    ),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar salones',
                          hintStyle: TextStyle(color: Color(0xFF637588)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Salones destacados
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Salones destacados',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Color(0xFF111418),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: salones.length,
                separatorBuilder: (_, __) => SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final salon = salones[i];
                  return Container(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Image.network(
                              salon['img']!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          salon['nombre']!,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: Color(0xFF111418),
                          ),
                        ),
                        Text(
                          "${salon['rating']} • ${salon['reviews']} reviews",
                          style: TextStyle(
                            color: Color(0xFF637588),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Categorías
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Categorías',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Color(0xFF111418),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: categorias
                    .map((cat) => Chip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              color: Color(0xFF111418),
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          backgroundColor: Color(0xFFF0F2F4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16),
                        ))
                    .toList(),
              ),
            ),
            Spacer(),
            // Bottom Navigation Bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF0F2F4)),
                ),
                color: Colors.white,
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home,
                    label: 'Inicio',
                    selected: true,
                  ),
                  _NavItem(
                    icon: Icons.search,
                    label: 'Buscar',
                  ),
                  _NavItem(
                    icon: Icons.favorite_border,
                    label: 'Favoritos',
                  ),
                  // Perfil: al tocar abre ProfileMenuPage
                  GestureDetector(
                    onTap: () {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProfileMenuPage(uid: uid)),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, color: Color(0xFF637588), size: 28),
                        Text(
                          'Perfil',
                          style: TextStyle(
                            color: Color(0xFF637588),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Color(0xFF111418) : Color(0xFF637588);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
