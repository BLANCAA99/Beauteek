import { Request, Response } from 'express';
import { db } from '../services/firebase.service';

// Crear promoción
export const createPromocion = async (req: Request, res: Response) => {
  try {
    const data = req.body;
    const docRef = await db.collection('promociones').add({
      ...data,
      fecha_creacion: new Date(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todas las promociones
export const getPromociones = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('promociones').get();
    const promociones = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(promociones);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener promoción por ID
export const getPromocionById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('promociones').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Promoción no encontrada' });
    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar promoción
export const updatePromocion = async (req: Request, res: Response) => {
  try {
    await db.collection('promociones').doc(req.params.id).update(req.body);
    res.json({ message: 'Promoción actualizada' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar promoción
export const deletePromocion = async (req: Request, res: Response) => {
  try {
    await db.collection('promociones').doc(req.params.id).delete();
    res.json({ message: 'Promoción eliminada' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
