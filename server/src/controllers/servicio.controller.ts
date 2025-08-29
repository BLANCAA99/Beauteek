import { Request, Response } from 'express';
import { db } from '../services/firebase.service';

// Crear servicio
export const createServicio = async (req: Request, res: Response) => {
  try {
    const data = req.body;
    const docRef = await db.collection('servicios').add({
      ...data,
      fecha_creacion: new Date(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los servicios
export const getServicios = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('servicios').get();
    const servicios = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(servicios);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener servicio por ID
export const getServicioById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('servicios').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Servicio no encontrado' });
    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar servicio
export const updateServicio = async (req: Request, res: Response) => {
  try {
    await db.collection('servicios').doc(req.params.id).update(req.body);
    res.json({ message: 'Servicio actualizado' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar servicio
export const deleteServicio = async (req: Request, res: Response) => {
  try {
    await db.collection('servicios').doc(req.params.id).delete();
    res.json({ message: 'Servicio eliminado' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
