import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme/app_theme.dart';
import 'api_constants.dart';
import 'introduccion_beauteek_page.dart';
import 'metodos_pago_salon_page.dart';

class ConfiguracionSalonPage extends StatefulWidget {
  const ConfiguracionSalonPage({Key? key}) : super(key: key);

  @override
  State<ConfiguracionSalonPage> createState() => _ConfiguracionSalonPageState();
}

class _ConfiguracionSalonPageState extends State<ConfiguracionSalonPage> {
  bool _notificarReservas = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _comercioId;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final idToken = await user.getIdToken();

      final comerciosUrl = Uri.parse('$apiBaseUrl/comercios');
      final comerciosResponse = await http.get(
        comerciosUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (comerciosResponse.statusCode == 200) {
        final List<dynamic> comercios = json.decode(comerciosResponse.body);
        final miComercio = comercios.firstWhere(
          (c) => c['uid_negocio'] == user.uid,
          orElse: () => null,
        );

        if (miComercio != null) {
          _comercioId = miComercio['id'];

          final configDoc = await FirebaseFirestore.instance
              .collection('configuracion_salon')
              .doc(_comercioId)
              .get();

          if (configDoc.exists) {
            final data = configDoc.data()!;
            setState(() {
              _notificarReservas = data['notificar_reservas'] ?? true;
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error cargando configuración: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarConfiguracion() async {
    if (_comercioId == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('configuracion_salon')
          .doc(_comercioId)
          .set({
        'notificar_reservas': _notificarReservas,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada'),
            backgroundColor: AppTheme.primaryOrange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            'Configuración del Salón',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange),
        ),
      );
    }
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
          'Configuración del Salón',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'CONFIGURACIÓN GENERAL',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _OpcionCard(
            icon: Icons.credit_card_rounded,
            iconColor: AppTheme.primaryOrange,
            backgroundColor: const Color(0xFF3B2612),
            titulo: 'Métodos de pago',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MetodosPagoSalonPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _OpcionCard(
            icon: Icons.lightbulb_outline_rounded,
            iconColor: AppTheme.primaryOrange,
            backgroundColor: const Color(0xFF3B2612),
            titulo: 'Introducción a Beauteek',
            subtitulo: 'Aprende cómo usar la aplicación',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IntroduccionBeauteekPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          const Text(
            'NOTIFICACIONES',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _OpcionConSwitch(
            icon: Icons.mail_rounded,
            iconColor: AppTheme.primaryOrange,
            backgroundColor: const Color(0xFF3B2612),
            titulo: 'Notificar nuevas reservas',
            value: _notificarReservas,
            onChanged: (value) {
              setState(() => _notificarReservas = value);
              _guardarConfiguracion();
            },
          ),
          const SizedBox(height: 24),
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: AppTheme.primaryOrange,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpcionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String titulo;
  final String? subtitulo;
  final VoidCallback onTap;

  const _OpcionCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.titulo,
    this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitulo!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionConSwitch extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String titulo;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OpcionConSwitch({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.titulo,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryOrange,
            activeTrackColor: AppTheme.primaryOrange.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}
