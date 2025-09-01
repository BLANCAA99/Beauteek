import { Request, Response } from 'express';
import { db } from '../services/firebase.service';
import { Horario } from '../modelos/horario.model';
import { z } from 'zod';

const horarioSchema = z.object({
  usuario_id: z.string().min(1),
  dia_semana: z.number().int().min(0).max(6),
  hora_inicio: z.string().min(1),
  hora_fin: z.string().min(1),
  activo: z.boolean(),
});

// Crear horario
export const createHorario = async (req: Request, res: Response) => {
  try {
    const parsed = horarioSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    const data: Horario = parsed.data;
    const docRef = await db.collection('horarios').add({
      ...data,
      fecha_creacion: new Date().toISOString(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los horarios
export const getHorarios = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('horarios').get();
    const horarios: Horario[] = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Horario));
    res.json(horarios);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener horario por ID
export const getHorarioById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('horarios').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Horario no encontrado' });
    res.json({ id: doc.id, ...doc.data() } as Horario);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar horario
export const updateHorario = async (req: Request, res: Response) => {
  try {
    const parsed = horarioSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    await db.collection('horarios').doc(req.params.id).update(parsed.data);
    res.json({ message: 'Horario actualizado' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar horario
export const deleteHorario = async (req: Request, res: Response) => {
  try {
    await db.collection('horarios').doc(req.params.id).delete();
    res.json({ message: 'Horario eliminado' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
