import { Request, Response } from "express";
import { db } from "../config/firebase";
import { Servicio } from "../modelos/servicio.model";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";

// Esquema: coerciona strings -> number
const servicioSchema = z.object({
  usuario_id: z.string().min(1),
  categoria_id: z.string().min(1),
  nombre: z.string().min(1),
  descripcion: z.string().optional(),
  duracion_min: z.coerce.number().int().min(1),
  precio: z.coerce.number().min(0),
  moneda: z.string().min(1),
  activo: z.coerce.boolean(), // por si viene "true"/"false"
});

// Crear servicio
export const createServicio = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = servicioSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    const data = parsed.data;
    const docRef = await db.collection("servicios").add({
      ...data,
      fecha_creacion: FieldValue.serverTimestamp(), // o new Date().toISOString()
    });
    res.status(201).json({ id: docRef.id, ...data });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener todos los servicios
export const getServicios = async (_req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection("servicios").get();
    const servicios: Servicio[] = snapshot.docs.map(
      (doc) => ({ id: doc.id, ...doc.data() } as Servicio)
    );
    res.json(servicios);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener servicio por ID
export const getServicioById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection("servicios").doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Servicio no encontrado" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() } as Servicio);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Actualizar servicio
export const updateServicio = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = servicioSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    await db.collection("servicios").doc(req.params.id).update(parsed.data);
    res.json({ message: "Servicio actualizado" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Eliminar servicio
export const deleteServicio = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("servicios").doc(req.params.id).delete();
    res.json({ message: "Servicio eliminado" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};