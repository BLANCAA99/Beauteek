import { Request, Response } from 'express';
import { db } from '../services/firebase.service';
import { Pago } from '../modelos/pago.model';
import { z } from 'zod';

const pagoSchema = z.object({
  cita_id: z.string().min(1),
  metodo: z.string().min(1),
  monto: z.number().min(0),
  moneda: z.string().min(1),
  estado: z.string().min(1),
  fecha_pago: z.string().optional(),
  referencia_ext: z.string().optional(),
});

// Crear pago
export const createPago = async (req: Request, res: Response) => {
  try {
    const parsed = pagoSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    const data: Pago = parsed.data;
    const docRef = await db.collection('pagos').add({
      ...data,
      fecha_creacion: new Date().toISOString(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los pagos
export const getPagos = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('pagos').get();
    const pagos: Pago[] = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Pago));
    res.json(pagos);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener pago por ID
export const getPagoById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('pagos').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Pago no encontrado' });
    res.json({ id: doc.id, ...doc.data() } as Pago);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar pago
export const updatePago = async (req: Request, res: Response) => {
  try {
    const parsed = pagoSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    await db.collection('pagos').doc(req.params.id).update(parsed.data);
    res.json({ message: 'Pago actualizado' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar pago
export const deletePago = async (req: Request, res: Response) => {
  try {
    await db.collection('pagos').doc(req.params.id).delete();
    res.json({ message: 'Pago eliminado' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
