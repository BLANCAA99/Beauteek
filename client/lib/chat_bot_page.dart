import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'api_constants.dart';

class ChatBotPage extends StatefulWidget {
  const ChatBotPage({Key? key}) : super(key: key);

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  bool _isSending = false;
  bool _isInitialized = false;
  String _sessionId = '';
  String _userRole = 'cliente'; // Rol del usuario

  @override
  void initState() {
    super.initState();
    _initializeBot();
  }

  Future<void> _initializeBot() async {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Obtener el rol del usuario
    await _loadUserRole();
    
    setState(() => _isInitialized = true);
    
    // Agregar mensaje de bienvenida después de cargar el rol
    _addWelcomeMessage();
  }
  
  Future<void> _loadUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _userRole = 'cliente';
        });
        return;
      }

      // Obtener el rol del usuario desde el backend
      final url = Uri.parse('$apiBaseUrl/api/users/uid/${user.uid}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        setState(() {
          _userRole = userData['rol'] as String? ?? 'cliente';
        });
        print('Rol del usuario cargado: $_userRole');
      } else {
        setState(() {
          _userRole = 'cliente';
        });
      }
    } catch (e) {
      print('Error al cargar rol del usuario: $e');
      setState(() {
        _userRole = 'cliente';
      });
    }
  }

  void _addWelcomeMessage() {
    final welcomeText = _userRole == 'salon'
        ? '¡Hola! Soy el asistente virtual de Beauteek para salones. ¿En qué puedo ayudarte con tu negocio?'
        : '¡Hola! Soy el asistente virtual de Beauteek. ¿En qué puedo ayudarte hoy?';
    
    setState(() {
      _messages.add({
        'text': welcomeText,
        'isUser': false,
        'timestamp': DateTime.now(),
      });
    });
  }

  Future<String> _detectIntent(String text, String sessionId) async {
    try {
      // Llamar al backend que maneja Dialogflow
      final url = Uri.parse('$apiBaseUrl/api/chatbot/message');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': text,
          'sessionId': sessionId,
          'userRole': _userRole, // Enviar el rol del usuario
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['response'] ?? _getLocalResponse(text);
        }
      }
      return _getLocalResponse(text);
      
    } catch (e) {
      return _getLocalResponse(text);
    }
  }

  String _getLocalResponse(String text) {
    final lowerText = text.toLowerCase().trim();
    final isSalon = _userRole == 'salon';

    if (lowerText.contains('hola') || lowerText.contains('buenos') || lowerText.contains('buenas')) {
      return isSalon
          ? '¡Hola! Soy el asistente de Beauteek para salones. ¿Necesitas ayuda con tu negocio?'
          : '¡Hola! Soy el asistente de Beauteek. ¿Cómo puedo ayudarte hoy?';
    } else if (lowerText.contains('reserva') || lowerText.contains('cita') || lowerText.contains('agendar')) {
      return isSalon
          ? 'Puedes ver las citas agendadas en tu salón desde el Calendario. Desde ahí también puedes cancelar o gestionar las citas de tus clientes.'
          : 'Para hacer una reserva, ve a la pestaña de búsqueda, selecciona un salón y elige el servicio que desees. ¿Te gustaría que te ayude con algo más?';
    } else if (lowerText.contains('servicio') || lowerText.contains('qué ofrecen')) {
      return isSalon
          ? 'Para editar tus servicios, ve a tu Perfil → Servicios. Ahí puedes agregar, editar o eliminar servicios, cambiar precios y duraciones.'
          : 'En Beauteek puedes encontrar servicios de peluquería, manicure, pedicure, tratamientos faciales, masajes y mucho más. Usa la búsqueda para ver todos los salones disponibles cerca de ti.';
    } else if (isSalon && (lowerText.contains('promocion') || lowerText.contains('descuento'))) {
      return 'Para gestionar promociones, ve a tu Perfil → Promociones. Puedes crear ofertas especiales, definir descuentos y establecer fechas de validez.';
    } else if (isSalon && (lowerText.contains('estadistica') || lowerText.contains('reporte'))) {
      return 'Puedes ver las estadísticas de tu salón en Perfil → Estadísticas. También hay reportes detallados en la sección de Reportes.';
    } else if (lowerText.contains('precio') || lowerText.contains('costo') || lowerText.contains('cuánto')) {
      return 'Los precios varían según el salón y el servicio. Puedes ver los precios detallados en el perfil de cada salón o usar la función "Comparar" para ver diferentes opciones.';
    } else if (lowerText.contains('horario') || lowerText.contains('abren') || lowerText.contains('cierran')) {
      return isSalon
          ? 'Para configurar tus horarios de atención, ve a Perfil → Configuración del Salón → Horarios. Ahí puedes establecer tu horario semanal.'
          : 'Cada salón tiene sus propios horarios. Puedes consultarlos en el perfil del salón antes de hacer tu reserva. ¿Buscas algún salón en particular?';
    } else if (lowerText.contains('cancelar')) {
      return 'Para cancelar una cita, ve a tu calendario, selecciona la cita y elige la opción de cancelar. Recuerda revisar las políticas de cancelación del salón.';
    } else if (lowerText.contains('gracias') || lowerText.contains('thank')) {
      return '¡De nada! Estoy aquí para ayudarte. Si tienes más preguntas, no dudes en escribirme.';
    } else if (lowerText.contains('adiós') || lowerText.contains('chao') || lowerText.contains('bye')) {
      return '¡Hasta pronto! Que tengas un excelente día. Vuelve cuando necesites ayuda.';
    } else if (lowerText.contains('ayuda') || lowerText.contains('help')) {
      return isSalon
          ? 'Puedo ayudarte con:\n• Gestionar tus citas\n• Editar servicios y precios\n• Configurar horarios\n• Crear promociones\n• Ver estadísticas\n• Configurar métodos de pago\n\n¿Qué necesitas?'
          : 'Puedo ayudarte con:\n• Hacer reservas\n• Buscar servicios\n• Comparar precios\n• Consultar horarios\n• Cancelar citas\n\n¿Qué necesitas?';
    } else {
      return isSalon
          ? 'Entiendo tu consulta. Te recomiendo explorar el menú de tu perfil donde encontrarás todas las opciones para gestionar tu salón. ¿Hay algo específico en lo que pueda ayudarte?'
          : 'Entiendo tu consulta. Te recomiendo explorar la app para encontrar salones cercanos y sus servicios. ¿Hay algo específico en lo que pueda ayudarte?';
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || !_isInitialized) return;

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _isSending = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      await Future.delayed(const Duration(milliseconds: 600));
      final response = await _detectIntent(text, _sessionId);
      
      setState(() {
        _messages.add({
          'text': response,
          'isUser': false,
          'timestamp': DateTime.now(),
        });
        _isSending = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({
          'text': 'Lo siento, ocurrió un error. Por favor intenta de nuevo.',
          'isUser': false,
          'timestamp': DateTime.now(),
        });
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Header con drag handle y botón cerrar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header content
                    Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF00BCD4), Color(0xFF2196F3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Asistente Beauteek',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'En línea',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Lista de mensajes
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _MessageBubble(
                      text: message['text'],
                      isUser: message['isUser'],
                      timestamp: message['timestamp'],
                    );
                  },
                ),
              ),

              // Indicador de escritura
              if (_isSending)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TypingDot(delay: 0),
                            const SizedBox(width: 4),
                            _TypingDot(delay: 200),
                            const SizedBox(width: 4),
                            _TypingDot(delay: 400),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Input de mensaje
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Escribe tu mensaje...',
                            hintStyle: TextStyle(color: AppTheme.textSecondary),
                            filled: true,
                            fillColor: AppTheme.darkBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (text) => _sendMessage(text),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF2196F3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white),
                          onPressed: _isSending
                              ? null
                              : () => _sendMessage(_messageController.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget para burbuja de mensaje
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const _MessageBubble({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00BCD4), Color(0xFF2196F3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primaryOrange
                    : AppTheme.cardBackground,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryOrange.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.person,
                color: AppTheme.primaryOrange,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Widget para animación de puntos de escritura
class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
