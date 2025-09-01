import { Request, Response } from 'express';
import { db } from '../services/firebase.service';
import { Servicio } from '../modelos/servicio.model';
import { z } from 'zod';

const servicioSchema = z.object({
  usuario_id: z.string().min(1),
  categoria_id: z.string().min(1),
  nombre: z.string().min(1),
  descripcion: z.string().optional(),
  duracion_min: z.number().int().min(1),
  precio: z.number().min(0),
  moneda: z.string().min(1),
  activo: z.boolean(),
});

// Crear servicio
export const createServicio = async (req: Request, res: Response) => {
  try {
    const parsed = servicioSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    const data: Servicio = parsed.data;
    const docRef = await db.collection('servicios').add({
      ...data,
      fecha_creacion: new Date().toISOString(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los servicios
export const getServicios = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('servicios').get();
    const servicios: Servicio[] = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Servicio));
    res.json(servicios);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener servicio por ID
export const getServicioById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('servicios').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Servicio no encontrado' });
    res.json({ id: doc.id, ...doc.data() } as Servicio);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar servicio
export const updateServicio = async (req: Request, res: Response) => {
  try {
    const parsed = servicioSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    await db.collection('servicios').doc(req.params.id).update(parsed.data);
    res.json({ message: 'Servicio actualizado' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar servicio
export const deleteServicio = async (req: Request, res: Response) => {
  try {
    await db.collection('servicios').doc(req.params.id).delete();
    res.json({ message: 'Servicio eliminado' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
