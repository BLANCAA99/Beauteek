import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

class IntroduccionBeauteekPage extends StatelessWidget {
  const IntroduccionBeauteekPage({Key? key}) : super(key: key);

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
          'Cómo usar Beauteek',
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryOrange.withOpacity(0.2),
                  AppTheme.primaryOrange.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppTheme.primaryOrange,
                  size: 56,
                ),
                SizedBox(height: 16),
                Text(
                  '¡Bienvenido a Beauteek!',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Guía rápida para administrar tu salón',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const _SeccionTitulo(numero: '1', titulo: 'Configuración Inicial'),
          const SizedBox(height: 16),
          const _PasoCard(
            icon: Icons.store_outlined,
            titulo: 'Perfil del salón',
            descripcion: 'Completa la información de tu salón: nombre, descripción, horarios de atención y ubicación.',
          ),
          const SizedBox(height: 12),
          const _PasoCard(
            icon: Icons.photo_library_outlined,
            titulo: 'Galería de fotos',
            descripcion: 'Sube fotos de tus instalaciones y trabajos realizados para atraer más clientes.',
          ),
          const SizedBox(height: 12),
          const _PasoCard(
            icon: Icons.content_cut_rounded,
            titulo: 'Servicios y precios',
            descripcion: 'Agrega todos los servicios que ofreces con sus respectivos precios y duración.',
          ),
          const SizedBox(height: 32),

          const _SeccionTitulo(numero: '2', titulo: 'Gestión Diaria'),
          const SizedBox(height: 16),
          const _PasoCard(
            icon: Icons.calendar_today_outlined,
            titulo: 'Citas del día',
            descripcion: 'En el inicio verás todas las citas del día. Puedes confirmarlas, cancelarlas o marcarlas como completadas.',
          ),
          const SizedBox(height: 12),
          const _PasoCard(
            icon: Icons.notifications_active_outlined,
            titulo: 'Notificaciones',
            descripcion: 'Recibirás notificaciones automáticas cuando un cliente reserve, cancele o te deje una reseña.',
          ),
          const SizedBox(height: 32),

          const _SeccionTitulo(numero: '3', titulo: 'Promociones y Marketing'),
          const SizedBox(height: 16),
          const _PasoCard(
            icon: Icons.local_offer_outlined,
            titulo: 'Crear promociones',
            descripcion: 'Crea ofertas especiales con descuentos para atraer más clientes y fidelizar los existentes.',
          ),
          const SizedBox(height: 12),
          const _PasoCard(
            icon: Icons.star_outlined,
            titulo: 'Reseñas',
            descripcion: 'Las reseñas de tus clientes te ayudarán a mejorar tu reputación y atraer nuevos clientes.',
          ),
          const SizedBox(height: 32),

          const _SeccionTitulo(numero: '4', titulo: 'Reportes y Estadísticas'),
          const SizedBox(height: 16),
          const _PasoCard(
            icon: Icons.bar_chart_outlined,
            titulo: 'Dashboard de estadísticas',
            descripcion: 'Consulta métricas en tiempo real: citas del día, ingresos, servicios más solicitados y más.',
          ),
          const SizedBox(height: 12),
          const _PasoCard(
            icon: Icons.analytics_outlined,
            titulo: 'Reportes detallados',
            descripcion: 'Analiza el rendimiento de tu salón por períodos: diario, semanal, mensual y anual.',
          ),
          const SizedBox(height: 32),

          const _SeccionTitulo(numero: '5', titulo: 'Configuración Avanzada'),
          const SizedBox(height: 16),
          const _PasoCard(
            icon: Icons.credit_card_rounded,
            titulo: 'Métodos de pago',
            descripcion: 'Configura qué métodos de pago aceptas: tarjeta (pasarela), transferencia o pago en local.',
          ),
          const SizedBox(height: 12),
          const _PasoCard(
            icon: Icons.lock_outlined,
            titulo: 'Privacidad y seguridad',
            descripcion: 'Gestiona tu contraseña y revisa la actividad reciente de tu cuenta.',
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryOrange.withOpacity(0.3),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded, color: AppTheme.primaryOrange, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Consejos para el éxito',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _ConsejoItem(texto: 'Mantén tu perfil actualizado con fotos recientes'),
                SizedBox(height: 8),
                _ConsejoItem(texto: 'Responde rápidamente a las reservas de clientes'),
                SizedBox(height: 8),
                _ConsejoItem(texto: 'Ofrece promociones regulares para atraer clientes'),
                SizedBox(height: 8),
                _ConsejoItem(texto: 'Revisa las estadísticas semanalmente para mejorar'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.help_outline_rounded, color: AppTheme.primaryOrange, size: 40),
                SizedBox(height: 12),
                Text(
                  '¿Necesitas ayuda?',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Visita el Centro de Ayuda o contáctanos si tienes alguna duda',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  final String numero;
  final String titulo;

  const _SeccionTitulo({required this.numero, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              numero,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          titulo,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _PasoCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descripcion;

  const _PasoCard({
    required this.icon,
    required this.titulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryOrange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descripcion,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsejoItem extends StatelessWidget {
  final String texto;

  const _ConsejoItem({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, color: AppTheme.primaryOrange, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
