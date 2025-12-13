import { Request, Response } from "express";
import { db } from "../config/firebase";
import { Resena } from "../modelos/resena.model";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";


const resenaSchema = z.object({
  usuario_salon_id: z.string().min(1),
  usuario_cliente_id: z.string().min(1),
  comercio_id: z.string().min(1),
  servicio_id: z.string().min(1),
  cita_id: z.string().optional(),
  calificacion: z.coerce.number().min(1).max(5),
  comentario: z.string().optional(),
  foto_url: z.string().optional(),
  fecha: z.string().optional(),
});

// Crear reseña
export const createResena = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = resenaSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    const data = parsed.data;

    const payload = {
      ...data,
      fecha: data.fecha ?? FieldValue.serverTimestamp(),
      fecha_creacion: FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection("resenas").add(payload);
    res.status(201).json({ id: docRef.id, ...data });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener todas las reseñas
export const getResenas = async (_req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection("resenas").get();
    const resenas: Resena[] = snapshot.docs.map(
      (doc) => ({ id: doc.id, ...doc.data() } as Resena)
    );
    res.json(resenas);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener reseña por ID
export const getResenaById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection("resenas").doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Reseña no encontrada" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() } as Resena);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Actualizar reseña
export const updateResena = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = resenaSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    const data = parsed.data;
    await db
      .collection("resenas")
      .doc(req.params.id)
      .update({ ...data, fecha_actualizacion: FieldValue.serverTimestamp() });

    res.json({ message: "Reseña actualizada" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Eliminar reseña
export const deleteResena = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("resenas").doc(req.params.id).delete();
    res.json({ message: "Reseña eliminada" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};