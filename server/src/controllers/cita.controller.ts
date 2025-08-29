import { Request, Response } from 'express';
import { db } from '../services/firebase.service';

// Crear cita
export const createCita = async (req: Request, res: Response) => {
  try {
    const data = req.body;
    const docRef = await db.collection('citas').add({
      ...data,
      fecha_creacion: new Date(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todas las citas
export const getCitas = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('citas').get();
    const citas = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(citas);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener cita por ID
export const getCitaById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('citas').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Cita no encontrada' });
    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar cita
export const updateCita = async (req: Request, res: Response) => {
  try {
    await db.collection('citas').doc(req.params.id).update(req.body);
    res.json({ message: 'Cita actualizada' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar cita
export const deleteCita = async (req: Request, res: Response) => {
  try {
    await db.collection('citas').doc(req.params.id).delete();
    res.json({ message: 'Cita eliminada' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
