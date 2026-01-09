import { onSchedule } from 'firebase-functions/v2/scheduler';
import { db } from '../config/firebase';
import { sendPushNotificationToUser } from '../services/notification.service';

/**
 * Cloud Function programada que se ejecuta todos los días a las 9:00 AM
 * Envía recordatorios de citas:
 * - Para citas que son mañana (24 horas antes)
 * - Para citas que son hoy
 */
export const sendDailyAppointmentReminders = onSchedule(
  {
    schedule: 'every day 09:00',
    timeZone: 'America/Tegucigalpa', // Zona horaria de Honduras
    region: 'us-central1',
  },
  async (event) => {
    console.log('[Recordatorios] Iniciando envío de recordatorios de citas...');

    try {
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      
      // Mañana (para recordatorio de 24 horas antes)
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);
      
      // Pasado mañana (límite para mañana)
      const dayAfterTomorrow = new Date(today);
      dayAfterTomorrow.setDate(dayAfterTomorrow.getDate() + 2);

      // Obtener citas pendientes o confirmadas que sean hoy o mañana
      const citasSnapshot = await db.collection('citas')
        .where('estado', 'in', ['pendiente', 'confirmada'])
        .get();

      if (citasSnapshot.empty) {
        console.log('[Recordatorios] No hay citas pendientes o confirmadas');
        return;
      }

      let recordatoriosEnviados = 0;
      let recordatoriosFallidos = 0;

      for (const doc of citasSnapshot.docs) {
        const cita = doc.data();
        const citaId = doc.id;

        // Extraer fecha de la cita
        let citaFecha: Date;
        
        // Manejar diferentes formatos de fecha_hora
        if (cita.fecha_hora) {
          if (typeof cita.fecha_hora === 'string') {
            citaFecha = new Date(cita.fecha_hora);
          } else if (cita.fecha_hora.toDate) {
            // Firestore Timestamp
            citaFecha = cita.fecha_hora.toDate();
          } else {
            continue; // Saltar si no se puede parsear la fecha
          }
        } else {
          continue; // No tiene fecha
        }

        const citaFechaSinHora = new Date(
          citaFecha.getFullYear(),
          citaFecha.getMonth(),
          citaFecha.getDate()
        );

        const userId = cita.usuario_cliente_id;
        if (!userId) continue;

        const servicioNombre = cita.servicio_nombre || 'tu servicio';
        const hora = citaFecha.toLocaleTimeString('es-HN', { 
          hour: '2-digit', 
          minute: '2-digit',
          hour12: true 
        });

        // Obtener nombre del salón
        let salonNombre = 'el salón';
        if (cita.comercio_id) {
          try {
            const comercioDoc = await db.collection('comercios').doc(cita.comercio_id).get();
            if (comercioDoc.exists) {
              salonNombre = comercioDoc.data()?.nombre || salonNombre;
            }
          } catch (error) {
            console.error(`Error obteniendo nombre del comercio: ${error}`);
          }
        }

        let notificationSent = false;

        // CASO 1: La cita es HOY
        if (citaFechaSinHora.getTime() === today.getTime()) {
          console.log(`[Recordatorios] Enviando recordatorio para cita HOY: ${citaId}`);
          
          notificationSent = await sendPushNotificationToUser(
            userId,
            {
              title: '¡Tu cita es hoy!',
              body: `Recuerda: ${servicioNombre} en ${salonNombre} hoy a las ${hora}`,
              data: {
                cita_id: citaId,
                fecha: citaFecha.toISOString(),
                hora: hora,
              },
            },
            {
              type: 'recordatorio_cita',
              entityId: citaId,
            }
          );
        }
        // CASO 2: La cita es MAÑANA (recordatorio de 24 horas antes)
        else if (citaFechaSinHora.getTime() === tomorrow.getTime()) {
          console.log(`[Recordatorios] Enviando recordatorio para cita MAÑANA: ${citaId}`);
          
          notificationSent = await sendPushNotificationToUser(
            userId,
            {
              title: 'Recordatorio de cita',
              body: `Mañana tienes: ${servicioNombre} en ${salonNombre} a las ${hora}`,
              data: {
                cita_id: citaId,
                fecha: citaFecha.toISOString(),
                hora: hora,
              },
            },
            {
              type: 'recordatorio_cita',
              entityId: citaId,
            }
          );
        }

        if (notificationSent) {
          recordatoriosEnviados++;
        } else if (citaFechaSinHora.getTime() === today.getTime() || 
                   citaFechaSinHora.getTime() === tomorrow.getTime()) {
          recordatoriosFallidos++;
        }
      }

      console.log(`[Recordatorios] Completado: ${recordatoriosEnviados} enviados, ${recordatoriosFallidos} fallidos`);
      
    } catch (error) {
      console.error('[Recordatorios] Error en función programada:', error);
    }
  }
);
