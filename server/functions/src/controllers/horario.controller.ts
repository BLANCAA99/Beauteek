import { Request, Response } from "express";
import { db } from "../config/firebase";
import { Horario } from "../modelos/horario.model";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";

// HH:mm 24h
const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

const horarioSchema = z.object({
  usuario_id: z.string().min(1),
  dia_semana: z.coerce.number().int().min(0).max(6), // 0=Dom ... 6=Sáb
  hora_inicio: z.string().regex(HHMM, "Formato HH:mm (00-23:00-59)"),
  hora_fin: z.string().regex(HHMM, "Formato HH:mm (00-23:00-59)"),
  activo: z.coerce.boolean(),
}).superRefine((data, ctx) => {
  // Validar que fin > inicio
  const toMinutes = (hhmm: string) => {
    const [h, m] = hhmm.split(":").map(Number);
    return h * 60 + m;
  };
  if (toMinutes(data.hora_fin) <= toMinutes(data.hora_inicio)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["hora_fin"],
      message: "La hora_fin debe ser mayor que hora_inicio.",
    });
  }
});

// Crear horario
export const createHorario = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = horarioSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    const data = parsed.data;
    const payload = {
      ...data,
      fecha_creacion: FieldValue.serverTimestamp(),
      fecha_actualizacion: FieldValue.serverTimestamp(),
    };
    const docRef = await db.collection("horarios").add(payload);
    res.status(201).json({ id: docRef.id, ...data });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener todos los horarios
export const getHorarios = async (_req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection("horarios").get();
    const horarios: Horario[] = snapshot.docs.map(
      (doc) => ({ id: doc.id, ...doc.data() } as Horario)
    );
    res.json(horarios);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener horario por ID
export const getHorarioById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection("horarios").doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Horario no encontrado" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() } as Horario);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Actualizar horario
export const updateHorario = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = horarioSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    const data = parsed.data;
    await db.collection("horarios").doc(req.params.id).update({
      ...data,
      fecha_actualizacion: FieldValue.serverTimestamp(),
    });
    res.json({ message: "Horario actualizado" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Eliminar horario
export const deleteHorario = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("horarios").doc(req.params.id).delete();
    res.json({ message: "Horario eliminado" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};