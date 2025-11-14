import { Request, Response } from "express";
import { db } from "../config/firebase";
import { Servicio } from "../modelos/servicio.model";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";

// Esquema: coerciona strings -> number
const servicioSchema = z.object({
  usuario_id: z.string().min(1),
  comercio_id: z.string().min(1),
  categoria_id: z.string().min(1),
  nombre: z.string().min(1),
  descripcion: z.string().optional().nullable(),
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

// Obtener todos los servicios (con filtro opcional por comercio_id)
export const getServicios = async (req: Request, res: Response): Promise<void> => {
  try {
    const { comercio_id } = req.query;

    let query = db.collection("servicios");

    // ✅ Filtrar por comercio_id si viene en query params
    if (comercio_id) {
      query = query.where("comercio_id", "==", comercio_id) as any;
      console.log(`🔍 Filtrando servicios por comercio_id: ${comercio_id}`);
    }

    const snapshot = await query.get();
    const servicios: Servicio[] = snapshot.docs.map(
      (doc) => ({ id: doc.id, ...doc.data() } as Servicio)
    );

    console.log(
      `📊 Servicios encontrados: ${servicios.length}${comercio_id ? ` para comercio ${comercio_id}` : ""}`
    );

    res.json(servicios);
    return;
  } catch (error: any) {
    console.error("❌ Error obteniendo servicios:", error);
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