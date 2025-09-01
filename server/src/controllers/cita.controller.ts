import { Request, Response } from 'express';
import { db } from '../services/firebase.service';
import { Cita } from '../modelos/cita.model';
import { z } from 'zod';

const citaSchema = z.object({
  usuario_salon_id: z.string().min(1),
  servicio_id: z.string().min(1),
  usuario_cliente_id: z.string().min(1),
  fecha_inicio: z.string().min(1),
  fecha_fin: z.string().min(1),
  estado: z.string().min(1),
  notas: z.string().optional(),
  origen: z.string().optional(),
  created_at: z.string().optional(),
});

// Crear cita
export const createCita = async (req: Request, res: Response) => {
  try {
    const parsed = citaSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    const data: Cita = parsed.data;
    const docRef = await db.collection('citas').add({
      ...data,
      fecha_creacion: new Date().toISOString(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todas las citas
export const getCitas = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('citas').get();
    const citas: Cita[] = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Cita));
    res.json(citas);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener cita por ID
export const getCitaById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('citas').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Cita no encontrada' });
    res.json({ id: doc.id, ...doc.data() } as Cita);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar cita
export const updateCita = async (req: Request, res: Response) => {
  try {
    const parsed = citaSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    await db.collection('citas').doc(req.params.id).update(parsed.data);
    res.json({ message: 'Cita actualizada' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar cita
export const deleteCita = async (req: Request, res: Response) => {
  try {
    await db.collection('citas').doc(req.params.id).delete();
    res.json({ message: 'Cita eliminada' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
