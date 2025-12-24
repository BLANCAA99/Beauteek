import { messaging } from 'firebase-admin';
import { db } from '../config/firebase';

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface NotificationOptions {
  type: 'nueva_cita' | 'cita_cancelada' | 'cita_confirmada' | 'recordatorio_cita' | 'nueva_promocion' | 'mensaje' | 'pago_confirmado' | 'pago_recibido' | 'nueva_resena';
  entityId?: string;
  imageUrl?: string;
}

/**
 * Envía una notificación push a un usuario específico
 */
export async function sendPushNotificationToUser(
  userId: string,
  payload: NotificationPayload,
  options: NotificationOptions
): Promise<boolean> {
  try {
    // Obtener el FCM token del usuario desde Firestore
    const userDoc = await db.collection('usuarios').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log(`❌ Usuario ${userId} no existe`);
      return false;
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcm_token;

    if (!fcmToken) {
      console.log(`⚠️ Usuario ${userId} no tiene FCM token`);
      return false;
    }

    // Construir el mensaje
    const message: messaging.Message = {
      token: fcmToken,
      notification: {
        title: payload.title,
        body: payload.body,
        imageUrl: options.imageUrl,
      },
      data: {
        type: options.type,
        entity_id: options.entityId || '',
        ...payload.data,
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'beauteek_notifications',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Enviar la notificación
    const response = await messaging().send(message);
    console.log(`✅ Notificación enviada exitosamente a ${userId}: ${response}`);
    return true;
  } catch (error: any) {
    // Si el token es inválido, eliminarlo de Firestore
    if (error.code === 'messaging/registration-token-not-registered' || 
        error.code === 'messaging/invalid-registration-token') {
      console.log(`🗑️ Token FCM inválido para usuario ${userId}, eliminando...`);
      try {
        await db.collection('usuarios').doc(userId).update({
          fcm_token: null,
          platform: null,
        });
      } catch (updateError) {
        console.error(`❌ Error al eliminar token inválido: ${updateError}`);
      }
    }
    
    console.error(`❌ Error enviando notificación a ${userId}:`, error);
    return false;
  }
}

/**
 * Envía notificaciones push a múltiples usuarios
 */
export async function sendPushNotificationToMultipleUsers(
  userIds: string[],
  payload: NotificationPayload,
  options: NotificationOptions
): Promise<{ success: number; failed: number }> {
  const results = await Promise.allSettled(
    userIds.map(userId => sendPushNotificationToUser(userId, payload, options))
  );

  const success = results.filter(r => r.status === 'fulfilled' && r.value === true).length;
  const failed = results.length - success;

  console.log(`📊 Notificaciones enviadas: ${success} exitosas, ${failed} fallidas`);
  
  return { success, failed };
}

/**
 * Envía notificación a todos los usuarios con un rol específico
 */
export async function sendPushNotificationByRole(
  role: 'cliente' | 'salon',
  payload: NotificationPayload,
  options: NotificationOptions
): Promise<{ success: number; failed: number }> {
  try {
    // Obtener todos los usuarios con ese rol y que tengan FCM token
    const usersSnapshot = await db
      .collection('usuarios')
      .where('rol', '==', role)
      .where('fcm_token', '!=', null)
      .get();

    const userIds = usersSnapshot.docs.map(doc => doc.id);
    
    console.log(`📤 Enviando notificación a ${userIds.length} usuarios con rol '${role}'`);

    return await sendPushNotificationToMultipleUsers(userIds, payload, options);
  } catch (error) {
    console.error(`❌ Error enviando notificaciones por rol:`, error);
    return { success: 0, failed: 0 };
  }
}

/**
 * Envía notificación a un topic (grupo de usuarios suscritos)
 */
export async function sendPushNotificationToTopic(
  topic: string,
  payload: NotificationPayload,
  options: NotificationOptions
): Promise<boolean> {
  try {
    const message: messaging.Message = {
      topic,
      notification: {
        title: payload.title,
        body: payload.body,
        imageUrl: options.imageUrl,
      },
      data: {
        type: options.type,
        entity_id: options.entityId || '',
        ...payload.data,
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'beauteek_notifications',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await messaging().send(message);
    console.log(`✅ Notificación enviada al topic '${topic}': ${response}`);
    return true;
  } catch (error) {
    console.error(`❌ Error enviando notificación al topic '${topic}':`, error);
    return false;
  }
}

/**
 * Envía recordatorio de cita 24 horas antes
 */
export async function sendAppointmentReminder(citaId: string, userId: string): Promise<boolean> {
  try {
    // Obtener datos de la cita
    const citaDoc = await db.collection('citas').doc(citaId).get();
    if (!citaDoc.exists) {
      console.log(`❌ Cita ${citaId} no encontrada`);
      return false;
    }

    const citaData = citaDoc.data();
    const fecha = citaData?.fecha;
    const hora = citaData?.hora;
    const servicioNombre = citaData?.servicio_nombre || 'Tu servicio';
    const salonNombre = citaData?.salon_nombre || 'Salón de belleza';

    return await sendPushNotificationToUser(
      userId,
      {
        title: '⏰ Recordatorio de Cita',
        body: `Tienes una cita de ${servicioNombre} en ${salonNombre} mañana a las ${hora}`,
        data: {
          fecha,
          hora,
        },
      },
      {
        type: 'recordatorio_cita',
        entityId: citaId,
      }
    );
  } catch (error) {
    console.error(`❌ Error enviando recordatorio de cita:`, error);
    return false;
  }
}
