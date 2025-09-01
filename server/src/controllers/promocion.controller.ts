import { Request, Response } from 'express';
import { db } from '../services/firebase.service';
import { Promocion } from '../modelos/promocion.model';
import { z } from 'zod';

const promocionSchema = z.object({
  usuario_id: z.string().min(1),
  nombre: z.string().min(1),
  descripcion: z.string().optional(),
  tipo_descuento: z.string().min(1),
  valor: z.number().min(0),
  fecha_inicio: z.string().min(1),
  fecha_fin: z.string().min(1),
  activo: z.boolean(),
});

// Crear promoción
export const createPromocion = async (req: Request, res: Response) => {
  try {
    const parsed = promocionSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    const data: Promocion = parsed.data;
    const docRef = await db.collection('promociones').add({
      ...data,
      fecha_creacion: new Date().toISOString(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todas las promociones
export const getPromociones = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('promociones').get();
    const promociones: Promocion[] = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Promocion));
    res.json(promociones);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener promoción por ID
export const getPromocionById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('promociones').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Promoción no encontrada' });
    res.json({ id: doc.id, ...doc.data() } as Promocion);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar promoción
export const updatePromocion = async (req: Request, res: Response) => {
  try {
    const parsed = promocionSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    await db.collection('promociones').doc(req.params.id).update(parsed.data);
    res.json({ message: 'Promoción actualizada' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar promoción
export const deletePromocion = async (req: Request, res: Response) => {
  try {
    await db.collection('promociones').doc(req.params.id).delete();
    res.json({ message: 'Promoción eliminada' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
