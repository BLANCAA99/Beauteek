import { Request, Response } from "express";
import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";
import { sendPushNotificationToUser } from "../services/notification.service";

// Crear pago
export const createPago = async (req: Request, res: Response): Promise<void> => {
  try {
    const { citaId, clienteId, monto, numeroTarjeta, nombreTitular } = req.body;

    if (!citaId || !clienteId || !monto) {
      res.status(400).json({ error: 'Faltan datos requeridos' });
      return;
    }

    console.log(`💳 Procesando pago para cita: ${citaId}`);

    // Obtener la cita
    const citaDoc = await db.collection('citas').doc(citaId).get();
    
    if (!citaDoc.exists) {
      res.status(404).json({ error: 'Cita no encontrada' });
      return;
    }

    const citaData = citaDoc.data();
    
    console.log('📄 Datos de la cita:', citaData);

    // ✅ El cliente paga el monto completo del servicio
    const montoServicio = monto || citaData?.precio || 0;

    // 💰 Cálculo de comisión (5% para Beauteek)
    const porcentajeComision = 5; // 5%
    const montoComision = parseFloat((montoServicio * (porcentajeComision / 100)).toFixed(2));
    const montoSalon = parseFloat((montoServicio - montoComision).toFixed(2));

    console.log(`💵 Monto total: ${montoServicio}, Comisión (5%): ${montoComision}, Monto para salón: ${montoSalon}`);

    // ✅ Solo incluir campos que NO sean undefined
    const pagoData: any = {
      cita_id: citaId,
      usuario_cliente_id: clienteId,
      monto: montoServicio, // Monto total que paga el cliente
      monto_comision: montoComision, // Lo que retiene Beauteek
      monto_salon: montoSalon, // Lo que recibe el salón
      porcentaje_comision: porcentajeComision, // 5%
      metodo_pago: 'tarjeta',
      estado: 'completado',
      fecha_pago: FieldValue.serverTimestamp(),
    };

    // ✅ Solo agregar campos opcionales si existen
    if (citaData?.comercio_id) {
      pagoData.comercio_id = citaData.comercio_id;
    }

    if (numeroTarjeta) {
      pagoData.ultimos_4_digitos = numeroTarjeta.slice(-4);
    }

    if (nombreTitular) {
      pagoData.titular = nombreTitular;
    }

    console.log('💾 Guardando pago:', pagoData);

    // Guardar el pago
    const pagoRef = await db.collection('pagos').add(pagoData);

    // Actualizar estado de pago de la cita
    await db.collection('citas').doc(citaId).update({
      estado_pago: 'pagado',
      fecha_pago: FieldValue.serverTimestamp(),
    });

    console.log(`✅ Pago procesado exitosamente: ${pagoRef.id}`);

    // 🔔 Enviar notificaciones de pago
    try {
      // Notificar al cliente
      await sendPushNotificationToUser(
        clienteId,
        {
          title: '✅ Pago Confirmado',
          body: `Tu pago de $${montoServicio} ha sido procesado exitosamente`,
        },
        {
          type: 'pago_confirmado',
          entityId: pagoRef.id,
        }
      );
      console.log(`✅ Notificación de pago enviada al cliente ${clienteId}`);

      // Notificar al salón
      if (citaData?.comercio_id) {
        const comercioDoc = await db.collection('comercios').doc(citaData.comercio_id).get();
        const comercioData = comercioDoc.data();
        const uidSalon = comercioData?.uid_negocio || comercioData?.usuario_id;

        if (uidSalon) {
          // Calcular el monto que recibirá el salón (ya calculado arriba)
          const montoSalonParaNotif = parseFloat((montoServicio * 0.95).toFixed(2));
          await sendPushNotificationToUser(
            uidSalon,
            {
              title: '💰 Pago Recibido',
              body: `Has recibido un pago. Monto a transferir: $${montoSalonParaNotif} (después de comisión 5%)`,
            },
            {
              type: 'pago_recibido',
              entityId: pagoRef.id,
            }
          );
          console.log(`✅ Notificación de pago enviada al salón ${uidSalon}`);
        }
      }
    } catch (notifError) {
      console.error('⚠️ Error enviando notificaciones de pago:', notifError);
    }

    res.status(201).json({
      mensaje: 'Pago procesado exitosamente',
      pagoId: pagoRef.id,
      monto: montoServicio,
      monto_comision: montoComision,
      monto_salon: montoSalon,
      porcentaje_comision: porcentajeComision,
    });
  } catch (error: any) {
    console.error('❌ Error procesando pago:', error);
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los pagos
export const getPagos = async (req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection('pagos').get();
    const pagos = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(pagos);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener pago por ID
export const getPagoById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection('pagos').doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: 'Pago no encontrado' });
      return;
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};