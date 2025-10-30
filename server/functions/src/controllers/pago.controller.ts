import { Request, Response } from "express";
import { db } from "../config/firebase";
import { Pago } from "../modelos/pago.model";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";

// Esquema robusto
const pagoSchema = z.object({
  cita_id: z.string().min(1),
  metodo: z.enum(["efectivo", "tarjeta", "transferencia", "paypal", "stripe", "otro"]),
  monto: z.coerce.number().min(0),
  moneda: z.string().min(1).max(10), // ej. "HNL", "USD"
  estado: z.enum(["pendiente", "pagado", "fallido", "reembolsado"]),
  fecha_pago: z.coerce.date().optional(),   // acepta ISO/string/date
  referencia_ext: z.string().optional(),
}).superRefine((data, ctx) => {
  // Si está pagado/reembolsado, debería tener fecha_pago
  if ((data.estado === "pagado" || data.estado === "reembolsado") && !data.fecha_pago) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["fecha_pago"],
      message: "Para estado 'pagado' o 'reembolsado' se recomienda enviar 'fecha_pago'.",
    });
  }
});

// Crear pago
export const createPago = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = pagoSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    const data = parsed.data;

    const payload = {
      ...data,
      fecha_pago: data.fecha_pago ?? null, // si no la mandan, queda null
      fecha_creacion: FieldValue.serverTimestamp(),
      fecha_actualizacion: FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection("pagos").add(payload);
    res.status(201).json({ id: docRef.id, ...data });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener todos los pagos
export const getPagos = async (_req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection("pagos").get();
    const pagos: Pago[] = snapshot.docs.map(
      (doc) => ({ id: doc.id, ...doc.data() } as Pago)
    );
    res.json(pagos);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener pago por ID
export const getPagoById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection("pagos").doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Pago no encontrado" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() } as Pago);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Actualizar pago
export const updatePago = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = pagoSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    const data = parsed.data;

    await db
      .collection("pagos")
      .doc(req.params.id)
      .update({
        ...data,
        fecha_actualizacion: FieldValue.serverTimestamp(),
      });

    res.json({ message: "Pago actualizado" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Eliminar pago
export const deletePago = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("pagos").doc(req.params.id).delete();
    res.json({ message: "Pago eliminado" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};