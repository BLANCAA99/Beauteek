import { Request, Response } from "express";
import { db } from "../config/firebase";
import { Promocion } from "../modelos/promocion.model";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";

// Esquema robusto
const promocionSchema = z.object({
  usuario_id: z.string().min(1),
  nombre: z.string().min(1),
  descripcion: z.string().optional(),
  tipo_descuento: z.enum(["porcentaje", "monto"]), // restringe valores
  valor: z.coerce.number().min(0),                 // coerce para aceptar "10" -> 10
  fecha_inicio: z.coerce.date(),                   // acepta ISO/fecha-string
  fecha_fin: z.coerce.date(),
  activo: z.coerce.boolean(),
}).superRefine((data, ctx) => {
  // porcentaje debe estar entre 0 y 100
  if (data.tipo_descuento === "porcentaje" && (data.valor < 0 || data.valor > 100)) {
    ctx.addIssue({
      code: "custom",
      path: ["valor"],
      message: "Para 'porcentaje', el valor debe estar entre 0 y 100.",
    });
  }
  // Rango de fechas válido
  if (data.fecha_fin < data.fecha_inicio) {
    ctx.addIssue({
      code: "custom",
      path: ["fecha_fin"],
      message: "La fecha_fin no puede ser anterior a fecha_inicio.",
    });
  }
});

// Crear promoción
export const createPromocion = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = promocionSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }

    const data = parsed.data;

    // Firestore Admin admite Date -> Timestamp automáticamente
    const payload = {
      ...data,
      fecha_creacion: FieldValue.serverTimestamp(),
      fecha_actualizacion: FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection("promociones").add(payload);
    res.status(201).json({ id: docRef.id, ...data });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener todas las promociones
export const getPromociones = async (_req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection("promociones").get();
    const promociones: Promocion[] = snapshot.docs.map(
      (doc) => ({ id: doc.id, ...doc.data() } as Promocion)
    );
    res.json(promociones);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener promoción por ID
export const getPromocionById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection("promociones").doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Promoción no encontrada" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() } as Promocion);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Actualizar promoción
export const updatePromocion = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = promocionSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }

    const data = parsed.data;

    await db
      .collection("promociones")
      .doc(req.params.id)
      .update({
        ...data,
        fecha_actualizacion: FieldValue.serverTimestamp(),
      });

    res.json({ message: "Promoción actualizada" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Eliminar promoción
export const deletePromocion = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("promociones").doc(req.params.id).delete();
    res.json({ message: "Promoción eliminada" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};