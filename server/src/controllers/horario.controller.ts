import { Request, Response } from 'express';
import { db } from '../services/firebase.service';

// Crear horario
export const createHorario = async (req: Request, res: Response) => {
  try {
    const data = req.body;
    const docRef = await db.collection('horarios').add({
      ...data,
      fecha_creacion: new Date(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los horarios
export const getHorarios = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('horarios').get();
    const horarios = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(horarios);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener horario por ID
export const getHorarioById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('horarios').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Horario no encontrado' });
    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar horario
export const updateHorario = async (req: Request, res: Response) => {
  try {
    await db.collection('horarios').doc(req.params.id).update(req.body);
    res.json({ message: 'Horario actualizado' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar horario
export const deleteHorario = async (req: Request, res: Response) => {
  try {
    await db.collection('horarios').doc(req.params.id).delete();
    res.json({ message: 'Horario eliminado' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
