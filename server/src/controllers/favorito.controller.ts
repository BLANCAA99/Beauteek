import { Request, Response } from 'express';
import { db } from '../services/firebase.service';
import { Favorito } from '../modelos/favorito.model';
import { z } from 'zod';

const favoritoSchema = z.object({
  usuario_cliente_id: z.string().min(1),
  usuario_salon_id: z.string().min(1),
  fecha: z.string().optional(),
});

// Crear favorito
export const createFavorito = async (req: Request, res: Response) => {
  try {
    const parsed = favoritoSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    const data: Favorito = parsed.data;
    const docRef = await db.collection('favoritos').add({
      ...data,
      fecha_creacion: new Date().toISOString(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los favoritos
export const getFavoritos = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('favoritos').get();
    const favoritos: Favorito[] = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Favorito));
    res.json(favoritos);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener favorito por ID
export const getFavoritoById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('favoritos').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Favorito no encontrado' });
    res.json({ id: doc.id, ...doc.data() } as Favorito);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar favorito
export const updateFavorito = async (req: Request, res: Response) => {
  try {
    const parsed = favoritoSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    await db.collection('favoritos').doc(req.params.id).update(parsed.data);
    res.json({ message: 'Favorito actualizado' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar favorito
export const deleteFavorito = async (req: Request, res: Response) => {
  try {
    await db.collection('favoritos').doc(req.params.id).delete();
    res.json({ message: 'Favorito eliminado' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
