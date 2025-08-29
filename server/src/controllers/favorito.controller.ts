import { Request, Response } from 'express';
import { db } from '../services/firebase.service';

// Crear favorito
export const createFavorito = async (req: Request, res: Response) => {
  try {
    const data = req.body;
    const docRef = await db.collection('favoritos').add({
      ...data,
      fecha_creacion: new Date(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los favoritos
export const getFavoritos = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('favoritos').get();
    const favoritos = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(favoritos);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener favorito por ID
export const getFavoritoById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('favoritos').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Favorito no encontrado' });
    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar favorito
export const updateFavorito = async (req: Request, res: Response) => {
  try {
    await db.collection('favoritos').doc(req.params.id).update(req.body);
    res.json({ message: 'Favorito actualizado' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar favorito
export const deleteFavorito = async (req: Request, res: Response) => {
  try {
    await db.collection('favoritos').doc(req.params.id).delete();
    res.json({ message: 'Favorito eliminado' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
