import { Router, Request, Response } from 'express';
import { SessionsClient } from '@google-cloud/dialogflow';

const router = Router();

// Configurar cliente de Dialogflow
const projectId = 'beauteek-b595e';
const path = require('path');
const credentialsPath = path.join(__dirname, '..', '..', 'credentials.json');

console.log('Cargando credenciales desde:', credentialsPath);

const sessionClient = new SessionsClient({
  keyFilename: credentialsPath,
});/**
 * POST /api/chatbot/message
 * Envía un mensaje al chatbot de Dialogflow
 */
router.post('/message', async (req: Request, res: Response) => {
  try {
    const { message, sessionId, userRole = 'cliente' } = req.body;

    if (!message || !sessionId) {
      return res.status(400).json({
        success: false,
        error: 'Se requieren "message" y "sessionId"',
      });
    }

    // Crear la sesión de Dialogflow
    const sessionPath = sessionClient.projectAgentSessionPath(projectId, sessionId);

    // Crear el request para Dialogflow
    const request = {
      session: sessionPath,
      queryInput: {
        text: {
          text: message,
          languageCode: 'es',
        },
      },
    };

    // Enviar mensaje a Dialogflow
    console.log('Enviando a Dialogflow:', { message, userRole });
    const [response] = await sessionClient.detectIntent(request);      
    const result = response.queryResult;
    
    const intentName = result?.intent?.displayName || '';
    
    console.log('Respuesta de Dialogflow:', {
      intent: intentName,
      confidence: result?.intentDetectionConfidence,
      fulfillmentText: result?.fulfillmentText,
      userRole: userRole
    });

    // Validar que el intent sea apropiado para el rol del usuario
    let responseText = result?.fulfillmentText || '';
    
    // Si el intent no coincide con el rol, usar respuesta apropiada
    const isClienteIntent = intentName.startsWith('cliente.');
    const isSalonIntent = intentName.startsWith('salon.');
    
    if (userRole === 'cliente' && isSalonIntent) {
      // Cliente pidiendo funcionalidad de salón
      responseText = 'Esa función es para salones. Como cliente, puedo ayudarte con: buscar salones, hacer reservas, ver servicios, comparar precios y más. ¿Qué necesitas?';
    } else if (userRole === 'salon' && isClienteIntent) {
      // Salón pidiendo funcionalidad de cliente
      responseText = 'Esa función es para clientes. Como salón, puedo ayudarte con: gestionar citas, editar servicios, ver estadísticas, configurar horarios, crear promociones y más. ¿Qué necesitas?';
    } else if (!responseText) {
      // Si no hay respuesta, usar fallback según el rol
      responseText = getFallbackResponse(message, userRole);
    }

    return res.json({
      success: true,
      response: responseText,
      intent: intentName || 'default',
      confidence: result?.intentDetectionConfidence || 0,
      userRole: userRole
    });
  } catch (error: any) {
    console.error('Error en chatbot:', error);
    
    // En caso de error, devolver respuesta local
    const userRole = req.body.userRole || 'cliente';
    const fallbackResponse = getFallbackResponse(req.body.message || '', userRole);
    
    return res.json({
      success: true,
      response: fallbackResponse,
      intent: 'fallback',
      confidence: 1.0,
      note: 'Usando respuesta local por error en Dialogflow',
    });
  }
});

/**
 * Respuestas locales de fallback
 */
function getFallbackResponse(text: string, userRole: string = 'cliente'): string {
  const lowerText = text.toLowerCase().trim();
  const isSalon = userRole === 'salon';

  if (lowerText.includes('hola') || lowerText.includes('buenos') || lowerText.includes('buenas')) {
    return isSalon 
      ? '¡Hola! 😊 Soy el asistente de Beauteek para salones. ¿Necesitas ayuda con tu negocio?'
      : '¡Hola! 😊 Soy el asistente de Beauteek. ¿Cómo puedo ayudarte hoy?';
  } else if (lowerText.includes('reserva') || lowerText.includes('cita') || lowerText.includes('agendar')) {
    return isSalon
      ? 'Puedes ver las citas agendadas en tu salón desde el Calendario 📅. Desde ahí también puedes cancelar o gestionar las citas de tus clientes.'
      : 'Para hacer una reserva, ve a la pestaña de búsqueda, selecciona un salón y elige el servicio que desees. ¿Te gustaría que te ayude con algo más?';
  } else if (lowerText.includes('servicio') || lowerText.includes('qué ofrecen')) {
    return isSalon
      ? 'Para editar tus servicios, ve a tu Perfil → Servicios. Ahí puedes agregar, editar o eliminar servicios, cambiar precios y duraciones.'
      : 'En Beauteek puedes encontrar servicios de peluquería, manicure, pedicure, tratamientos faciales, masajes y mucho más. Usa la búsqueda para ver todos los salones disponibles cerca de ti.';
  } else if (isSalon && (lowerText.includes('promocion') || lowerText.includes('descuento'))) {
    return 'Para gestionar promociones, ve a tu Perfil → Promociones. Puedes crear ofertas especiales, definir descuentos y establecer fechas de validez.';
  } else if (isSalon && (lowerText.includes('estadistica') || lowerText.includes('reporte'))) {
    return 'Puedes ver las estadísticas de tu salón en Perfil → Estadísticas. También hay reportes detallados en la sección de Reportes.';
  } else if (lowerText.includes('precio') || lowerText.includes('costo') || lowerText.includes('cuánto')) {
    return 'Los precios varían según el salón y el servicio. Puedes ver los precios detallados en el perfil de cada salón o usar la función "Comparar" para ver diferentes opciones.';
  } else if (lowerText.includes('horario') || lowerText.includes('abren') || lowerText.includes('cierran')) {
    return isSalon
      ? 'Para configurar tus horarios de atención, ve a Perfil → Configuración del Salón → Horarios. Ahí puedes establecer tu horario semanal.'
      : 'Cada salón tiene sus propios horarios. Puedes consultarlos en el perfil del salón antes de hacer tu reserva. ¿Buscas algún salón en particular?';
  } else if (lowerText.includes('cancelar')) {
    return 'Para cancelar una cita, ve a tu calendario 📅, selecciona la cita y elige la opción de cancelar. Recuerda revisar las políticas de cancelación del salón.';
  } else if (lowerText.includes('gracias') || lowerText.includes('thank')) {
    return '¡De nada! 😊 Estoy aquí para ayudarte. Si tienes más preguntas, no dudes en escribirme.';
  } else if (lowerText.includes('adiós') || lowerText.includes('chao') || lowerText.includes('bye')) {
    return '¡Hasta pronto! 👋 Que tengas un excelente día. Vuelve cuando necesites ayuda.';
  } else if (lowerText.includes('ayuda') || lowerText.includes('help')) {
    return isSalon
      ? 'Puedo ayudarte con:\n• Gestionar tus citas\n• Editar servicios y precios\n• Configurar horarios\n• Crear promociones\n• Ver estadísticas\n• Configurar métodos de pago\n\n¿Qué necesitas?'
      : 'Puedo ayudarte con:\n• Hacer reservas\n• Buscar servicios\n• Comparar precios\n• Consultar horarios\n• Cancelar citas\n\n¿Qué necesitas?';
  } else {
    return isSalon
      ? 'Entiendo tu consulta. Te recomiendo explorar el menú de tu perfil donde encontrarás todas las opciones para gestionar tu salón. ¿Hay algo específico en lo que pueda ayudarte?'
      : 'Entiendo tu consulta. Te recomiendo explorar la app para encontrar salones cercanos y sus servicios. ¿Hay algo específico en lo que pueda ayudarte?';
  }
}

export default router;
