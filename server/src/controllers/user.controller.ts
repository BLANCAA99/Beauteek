import { Request, Response } from 'express';
import { db } from '../services/firebase.service';
import { Usuario } from '../modelos/usuario.model';
import { z } from 'zod';

const usuarioSchema = z.object({
  nombre_completo: z.string().min(1),
  email: z.string().email(),
  telefono: z.string().optional(),
  rol: z.string().optional(),
  foto_url: z.string().url().optional(),
  direccion: z.string().optional(),
  geo_lat: z.number().optional(),
  geo_lng: z.number().optional(),
  estado: z.string().optional(),
  fecha_creacion: z.string().optional(),
});

// Crear usuario
export const createUser = async (req: Request, res: Response) => {
  try {
    const parsed = usuarioSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    const data: Usuario = parsed.data;
    const docRef = await db.collection('usuarios').add({
      ...data,
      fecha_creacion: new Date().toISOString(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los usuarios
export const getUsers = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('usuarios').get();
    const users: Usuario[] = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Usuario));
    res.json(users);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener usuario por ID
export const getUserById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('usuarios').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json({ id: doc.id, ...doc.data() } as Usuario);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar usuario
export const updateUser = async (req: Request, res: Response) => {
  try {
    const parsed = usuarioSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.errors });
    }
    await db.collection('usuarios').doc(req.params.id).update(parsed.data);
    res.json({ message: 'Usuario actualizado' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar usuario
export const deleteUser = async (req: Request, res: Response) => {
  try {
    await db.collection('usuarios').doc(req.params.id).delete();
    res.json({ message: 'Usuario eliminado' });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};