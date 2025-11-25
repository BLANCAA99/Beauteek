import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

class CentroAyudaPage extends StatefulWidget {
  const CentroAyudaPage({Key? key}) : super(key: key);

  @override
  State<CentroAyudaPage> createState() => _CentroAyudaPageState();
}

class _CentroAyudaPageState extends State<CentroAyudaPage> {
  int? _faqExpandido;

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
          'Centro de Ayuda',
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
          // Preguntas Frecuentes
          const Text(
            'Preguntas Frecuentes',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _FAQItem(
            pregunta: '¿Cómo agendar una nueva cita?',
            respuesta:
                'Para agendar una nueva cita, ve a la sección de \'Calendario\', pulsa en el horario deseado y selecciona el servicio y cliente correspondiente. Confirma los detalles para finalizar.',
            isExpanded: _faqExpandido == 0,
            onTap: () {
              setState(() {
                _faqExpandido = _faqExpandido == 0 ? null : 0;
              });
            },
          ),
          const SizedBox(height: 12),
          _FAQItem(
            pregunta: '¿Puedo gestionar mi inventario?',
            respuesta:
                'Actualmente estamos trabajando en la funcionalidad de gestión de inventario. Estará disponible próximamente en una actualización futura.',
            isExpanded: _faqExpandido == 1,
            onTap: () {
              setState(() {
                _faqExpandido = _faqExpandido == 1 ? null : 1;
              });
            },
          ),
          const SizedBox(height: 12),
          _FAQItem(
            pregunta: 'Problemas con los pagos',
            respuesta:
                'Si tienes problemas con los pagos, verifica que tu método de pago esté activo y actualizado. Si el problema persiste, contacta a nuestro soporte técnico.',
            isExpanded: _faqExpandido == 2,
            onTap: () {
              setState(() {
                _faqExpandido = _faqExpandido == 2 ? null : 2;
              });
            },
          ),
          const SizedBox(height: 32),

          // Tutoriales
          const Text(
            'Tutoriales',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _TutorialCard(
            icon: Icons.play_circle_outline,
            titulo: 'Primeros pasos en Beauteek',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Abriendo tutorial...'),
                  backgroundColor: AppTheme.primaryOrange,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _TutorialCard(
            icon: Icons.calendar_month_rounded,
            titulo: 'Optimiza tu calendario',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Abriendo tutorial...'),
                  backgroundColor: AppTheme.primaryOrange,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _TutorialCard(
            icon: Icons.notifications_active_rounded,
            titulo: 'Cómo usar las notificaciones',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Abriendo tutorial...'),
                  backgroundColor: AppTheme.primaryOrange,
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Botón Contactar Soporte
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Abriendo chat de soporte...'),
                  backgroundColor: AppTheme.primaryOrange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Contactar Soporte',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String pregunta;
  final String respuesta;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FAQItem({
    required this.pregunta,
    required this.respuesta,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pregunta,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 300),
                  turns: isExpanded ? 0.5 : 0,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Text(
                respuesta,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final VoidCallback onTap;

  const _TutorialCard({
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
                color: AppTheme.primaryOrange.withOpacity(0.15),
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
