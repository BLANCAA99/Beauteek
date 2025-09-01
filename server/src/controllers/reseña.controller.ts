import { Request, Response } from 'express';
import { db } from '../services/firebase.service';
import { Resena } from '../modelos/resena.model';
import { z } from 'zod';

const resenaSchema = z.object({
  usuario_salon_id: z.string().min(1),
  usuario_cliente_id: z.string().min(1),
  servicio_id: z.string().min(1),
  calificacion: z.number().min(1).max(5),
  comentario: z.string().optional(),
  fecha: z.string().min(1),
});

export const createResena = async (req: Request, res: Response) => {
  try {
    const parsed = resenaSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    const data: Resena = parsed.data;
    const docRef = await db.collection('resenas').add(data);
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const getResenas = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('resenas').get();
    const resenas: Resena[] = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Resena));
    res.json(resenas);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const getResenaById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('resenas').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Reseña no encontrada' });
    res.json({ id: doc.id, ...doc.data() } as Resena);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const updateResena = async (req: Request, res: Response) => {
  try {
    const parsed = resenaSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    await db.collection('resenas').doc(req.params.id).update(parsed.data);
    res.json({ message: 'Reseña actualizada' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const deleteResena = async (req: Request, res: Response) => {
  try {
    await db.collection('resenas').doc(req.params.id).delete();
    res.json({ message: 'Reseña eliminada' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
