import { Router, Request, Response } from 'express';
import { SessionsClient } from '@google-cloud/dialogflow';

const router = Router();

// Configurar cliente de Dialogflow
const projectId = 'beauteek-b595e';
const path = require('path');
const credentialsPath = path.join(__dirname, '..', '..', 'credentials.json');

console.log('🔑 Cargando credenciales desde:', credentialsPath);

const sessionClient = new SessionsClient({
  keyFilename: credentialsPath,
});/**
 * POST /api/chatbot/message
 * Envía un mensaje al chatbot de Dialogflow
 */
router.post('/message', async (req: Request, res: Response) => {
  try {
    const { message, sessionId } = req.body;

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
    console.log('📤 Enviando a Dialogflow:', message);
    const [response] = await sessionClient.detectIntent(request);      
    const result = response.queryResult;
    
    console.log('📥 Respuesta de Dialogflow:', {
      intent: result?.intent?.displayName,
      confidence: result?.intentDetectionConfidence,
      fulfillmentText: result?.fulfillmentText,
      hasMessages: result?.fulfillmentMessages?.length || 0
    });

    // Respuesta local como fallback
    const fallbackResponse = getFallbackResponse(message);

    return res.json({
      success: true,
      response: result?.fulfillmentText || fallbackResponse,
      intent: result?.intent?.displayName || 'default',
      confidence: result?.intentDetectionConfidence || 0,
    });  } catch (error: any) {
    console.error('❌ Error en chatbot:', error);
    
    // En caso de error, devolver respuesta local
    const fallbackResponse = getFallbackResponse(req.body.message || '');
    
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
function getFallbackResponse(text: string): string {
  const lowerText = text.toLowerCase().trim();

  if (lowerText.includes('hola') || lowerText.includes('buenos') || lowerText.includes('buenas')) {
    return '¡Hola! 😊 Soy el asistente de Beauteek. ¿Cómo puedo ayudarte hoy?';
  } else if (lowerText.includes('reserva') || lowerText.includes('cita') || lowerText.includes('agendar')) {
    return 'Para hacer una reserva, ve a la pestaña de búsqueda 🔍, selecciona un salón y elige el servicio que desees. ¿Te gustaría que te ayude con algo más?';
  } else if (lowerText.includes('servicio') || lowerText.includes('qué ofrecen')) {
    return 'En Beauteek puedes encontrar servicios de peluquería, manicure, pedicure, tratamientos faciales, masajes y mucho más. Usa la búsqueda para ver todos los salones disponibles cerca de ti.';
  } else if (lowerText.includes('precio') || lowerText.includes('costo') || lowerText.includes('cuánto')) {
    return 'Los precios varían según el salón y el servicio. Puedes ver los precios detallados en el perfil de cada salón o usar la función "Comparar" para ver diferentes opciones.';
  } else if (lowerText.includes('horario') || lowerText.includes('abren') || lowerText.includes('cierran')) {
    return 'Cada salón tiene sus propios horarios. Puedes consultarlos en el perfil del salón antes de hacer tu reserva. ¿Buscas algún salón en particular?';
  } else if (lowerText.includes('cancelar')) {
    return 'Para cancelar una cita, ve a tu calendario 📅, selecciona la cita y elige la opción de cancelar. Recuerda revisar las políticas de cancelación del salón.';
  } else if (lowerText.includes('gracias') || lowerText.includes('thank')) {
    return '¡De nada! 😊 Estoy aquí para ayudarte. Si tienes más preguntas, no dudes en escribirme.';
  } else if (lowerText.includes('adiós') || lowerText.includes('chao') || lowerText.includes('bye')) {
    return '¡Hasta pronto! 👋 Que tengas un excelente día. Vuelve cuando necesites ayuda.';
  } else if (lowerText.includes('ayuda') || lowerText.includes('help')) {
    return 'Puedo ayudarte con:\n• Hacer reservas\n• Buscar servicios\n• Comparar precios\n• Consultar horarios\n• Cancelar citas\n\n¿Qué necesitas?';
  } else {
    return 'Entiendo tu consulta. Te recomiendo explorar la app para encontrar salones cercanos y sus servicios. ¿Hay algo específico en lo que pueda ayudarte?';
  }
}

export default router;
