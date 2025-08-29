import { Request, Response } from 'express';
import { db } from '../services/firebase.service';

// Crear usuario
export const createUser = async (req: Request, res: Response) => {
  try {
    const data = req.body;
    const docRef = await db.collection('usuarios').add({
      ...data,
      fecha_creacion: new Date(),
    });
    res.status(201).json({ id: docRef.id, ...data });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener todos los usuarios
export const getUsers = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('usuarios').get();
    const users = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Obtener usuario por ID
export const getUserById = async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('usuarios').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar usuario
export const updateUser = async (req: Request, res: Response) => {
  try {
    await db.collection('usuarios').doc(req.params.id).update(req.body);
    res.json({ message: 'Usuario actualizado' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar usuario
export const deleteUser = async (req: Request, res: Response) => {
  try {
    await db.collection('usuarios').doc(req.params.id).delete();
    res.json({ message: 'Usuario eliminado' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};