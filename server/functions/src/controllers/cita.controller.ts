import { Request, Response } from "express";
import { db } from "../config/firebase";
import { Cita } from "../modelos/cita.model";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";

// Regex ISO o "YYYY-MM-DDTHH:mm"
const ISO_DATETIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/;

// Esquema robusto
const citaSchema = z
  .object({
    usuario_salon_id: z.string().min(1),
    servicio_id: z.string().min(1),
    usuario_cliente_id: z.string().min(1),
    fecha_inicio: z.string().regex(ISO_DATETIME, "Formato esperado: YYYY-MM-DDTHH:mm"),
    fecha_fin: z.string().regex(ISO_DATETIME, "Formato esperado: YYYY-MM-DDTHH:mm"),
    estado: z.enum(["pendiente", "confirmada", "cancelada", "completada"]),
    notas: z.string().optional(),
    origen: z.string().optional(),
    created_at: z.coerce.date().optional(),
  })
  .superRefine((data, ctx) => {
    // Validar que fecha_fin sea posterior a fecha_inicio
    const ini = new Date(data.fecha_inicio);
    const fin = new Date(data.fecha_fin);
    if (fin <= ini) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["fecha_fin"],
        message: "La fecha_fin debe ser posterior a fecha_inicio.",
      });
    }
  });

// Crear cita
export const createCita = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = citaSchema.safeParse(req.body);
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

    const docRef = await db.collection("citas").add(payload);
    res.status(201).json({ id: docRef.id, ...data });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener todas las citas
export const getCitas = async (_req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection("citas").get();
    const citas: Cita[] = snapshot.docs.map(
      (doc) => ({ id: doc.id, ...doc.data() } as Cita)
    );
    res.json(citas);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener cita por ID
export const getCitaById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection("citas").doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Cita no encontrada" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() } as Cita);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Actualizar cita
export const updateCita = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = citaSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }

    const data = parsed.data;
    await db
      .collection("citas")
      .doc(req.params.id)
      .update({ ...data, fecha_actualizacion: FieldValue.serverTimestamp() });

    res.json({ message: "Cita actualizada" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Eliminar cita
export const deleteCita = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("citas").doc(req.params.id).delete();
    res.json({ message: "Cita eliminada" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};