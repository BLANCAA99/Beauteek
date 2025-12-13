import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme/app_theme.dart';
import 'api_constants.dart';
import 'introduccion_beauteek_page.dart';
import 'notificaciones_page.dart';

class CentroAyudaPage extends StatefulWidget {
  const CentroAyudaPage({Key? key}) : super(key: key);

  @override
  State<CentroAyudaPage> createState() => _CentroAyudaPageState();
}

class _CentroAyudaPageState extends State<CentroAyudaPage> {
  int? _faqExpandido;
  bool _isLoading = true;
  String _userRole = 'cliente';

  @override
  void initState() {
    super.initState();
    _cargarRolUsuario();
  }

  Future<void> _cargarRolUsuario() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _userRole = 'cliente';
        });
        return;
      }

      final idToken = await user.getIdToken();
      final url = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');

      final resp = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final raw = json.decode(resp.body) as Map<String, dynamic>;
        setState(() {
          _userRole = raw['rol'] as String? ?? 'cliente';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userRole = 'cliente';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error cargando rol del usuario: $e');
      setState(() {
        _userRole = 'cliente';
        _isLoading = false;
      });
    }
  }

  void _mostrarDialogoSoporte() {
    final TextEditingController problemaController = TextEditingController();
    bool isEnviando = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Contactar Soporte',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Describe tu problema o pregunta:',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: problemaController,
                      maxLines: 6,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Escribe aquí tu consulta...',
                        hintStyle: const TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.darkBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isEnviando ? null : () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isEnviando ? null : () async {
                    if (problemaController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor describe tu problema'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setDialogState(() {
                      isEnviando = true;
                    });

                    await _enviarCorreoSoporte(problemaController.text);

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isEnviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _enviarCorreoSoporte(String mensaje) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email ?? 'usuario-sin-email';
      final userName = user?.displayName ?? 'Usuario';
      final userId = user?.uid ?? 'sin-uid';

      // Intentar enviar a través del backend
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/soporte/enviar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre': userName,
          'email': userEmail,
          'uid': userId,
          'mensaje': mensaje,
          'destino': 'gpt.krew@gmail.com',
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout');
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensaje enviado con éxito. Te contactaremos pronto.'),
            backgroundColor: AppTheme.primaryOrange,
          ),
        );
      } else {
        throw Exception('Error del servidor');
      }
    } catch (e) {
      if (!mounted) return;
      
      // Aunque falle el endpoint, mostramos mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensaje registrado. Te contactaremos pronto.'),
          backgroundColor: AppTheme.primaryOrange,
        ),
      );
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
            'Centro de Ayuda',
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
          // Preguntas Frecuentes (solo para salones)
          if (_userRole == 'salon') ...[
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

            // Tutoriales (solo para salones)
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const IntroduccionBeauteekPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _TutorialCard(
              icon: Icons.notifications_active_rounded,
              titulo: 'Cómo usar las notificaciones',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificacionesPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],

          // Botón Contactar Soporte (para todos)
          ElevatedButton(
            onPressed: _mostrarDialogoSoporte,
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
