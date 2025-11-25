import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'cambiar_contrasena_page.dart';

class PrivacidadSeguridadPage extends StatefulWidget {
  const PrivacidadSeguridadPage({Key? key}) : super(key: key);

  @override
  State<PrivacidadSeguridadPage> createState() => _PrivacidadSeguridadPageState();
}

class _PrivacidadSeguridadPageState extends State<PrivacidadSeguridadPage> {
  bool _autenticacionDosFactores = true;

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
          'Privacidad y Seguridad',
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
          // Sección: Acceso a la cuenta
          const Text(
            'ACCESO A LA CUENTA',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _OpcionCard(
            icon: Icons.lock_outline,
            titulo: 'Cambiar contraseña',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CambiarContrasenaPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _OpcionConSwitch(
            icon: Icons.shield_outlined,
            titulo: 'Autenticación de dos factores',
            subtitulo: 'Activado',
            value: _autenticacionDosFactores,
            onChanged: (value) {
              setState(() => _autenticacionDosFactores = value);
            },
          ),
          const SizedBox(height: 32),

          // Sección: Actividad
          const Text(
            'ACTIVIDAD',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _OpcionCard(
            icon: Icons.history_rounded,
            titulo: 'Actividad reciente',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Función en desarrollo'),
                  backgroundColor: AppTheme.primaryOrange,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _OpcionCard(
            icon: Icons.devices_rounded,
            titulo: 'Gestionar dispositivos',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Función en desarrollo'),
                  backgroundColor: AppTheme.primaryOrange,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OpcionCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final VoidCallback onTap;

  const _OpcionCard({
    required this.icon,
    required this.titulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
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
  final String titulo;
  final String subtitulo;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OpcionConSwitch({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryOrange,
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
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
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
