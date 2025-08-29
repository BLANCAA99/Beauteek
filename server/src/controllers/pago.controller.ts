import { Request, Response } from 'express';
import { db } from '../services/firebase.service';

// Crear pago
export const createPago = async (req: Request, res: Response) => {
  try {
    const data = req.body;
    const docRef = await db.collection('pagos').add({
      ...data,
      fecha_creacion: new Date(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los pagos
export const getPagos = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('pagos').get();
    const pagos = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(pagos);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener pago por ID
export const getPagoById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('pagos').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Pago no encontrado' });
    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar pago
export const updatePago = async (req: Request, res: Response) => {
  try {
    await db.collection('pagos').doc(req.params.id).update(req.body);
    res.json({ message: 'Pago actualizado' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar pago
export const deletePago = async (req: Request, res: Response) => {
  try {
    await db.collection('pagos').doc(req.params.id).delete();
    res.json({ message: 'Pago eliminado' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
