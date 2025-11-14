import { Request, Response } from "express";
import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";

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

    // Calcular comisión y total
    const montoServicio = monto || citaData?.precio || 0;
    const comision = montoServicio * 0.10;
    const total = montoServicio + comision;

    // ✅ Solo incluir campos que NO sean undefined
    const pagoData: any = {
      cita_id: citaId,
      usuario_cliente_id: clienteId,
      monto: montoServicio,
      comision: comision,
      total: total,
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

    res.status(201).json({
      mensaje: 'Pago procesado exitosamente',
      pagoId: pagoRef.id,
      monto: montoServicio,
      comision: comision,
      total: total,
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