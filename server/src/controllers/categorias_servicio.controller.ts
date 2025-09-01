import { Request, Response } from 'express';
import { db } from '../services/firebase.service';
import { CategoriaServicio } from '../modelos/categoria_servicio.model';
import { z } from 'zod';

const categoriaServicioSchema = z.object({
  usuario_id: z.string().min(1),
  nombre: z.string().min(1),
  descripcion: z.string().optional(),
});

// Crear categoría de servicio
export const createCategoriaServicio = async (req: Request, res: Response) => {
  try {
    const parsed = categoriaServicioSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    const data: CategoriaServicio = parsed.data;
    const docRef = await db.collection('categorias_servicio').add({
      ...data,
      fecha_creacion: new Date().toISOString(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todas las categorías de servicio
export const getCategoriasServicio = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('categorias_servicio').get();
    const categorias: CategoriaServicio[] = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as CategoriaServicio));
    res.json(categorias);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener categoría de servicio por ID
export const getCategoriaServicioById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('categorias_servicio').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Categoría no encontrada' });
    res.json({ id: doc.id, ...doc.data() } as CategoriaServicio);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar categoría de servicio
export const updateCategoriaServicio = async (req: Request, res: Response) => {
  try {
    const parsed = categoriaServicioSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    await db.collection('categorias_servicio').doc(req.params.id).update(parsed.data);
    res.json({ message: 'Categoría actualizada' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar categoría de servicio
export const deleteCategoriaServicio = async (req: Request, res: Response) => {
  try {
    await db.collection('categorias_servicio').doc(req.params.id).delete();
    res.json({ message: 'Categoría eliminada' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
