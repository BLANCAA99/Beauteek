import { Request, Response } from "express";
import { db } from "../config/firebase";
import { Promocion } from "../modelos/promocion.model";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";
import { sendPushNotificationByRole } from "../services/notification.service";

// Esquema robusto
const promocionSchema = z.object({
  comercio_id: z.string().min(1),
  servicio_id: z.string().min(1),
  servicio_nombre: z.string().min(1),
  foto_url: z.string().optional(),
  descripcion: z.string().optional(),
  tipo_descuento: z.enum(["porcentaje", "monto"]),
  valor: z.coerce.number().min(0),
  precio_original: z.coerce.number().min(0).optional(),
  precio_con_descuento: z.coerce.number().min(0).optional(),
  fecha_inicio: z.coerce.date(),
  fecha_fin: z.coerce.date(),
  activo: z.coerce.boolean(),
}).superRefine((data, ctx) => {
  if (data.tipo_descuento === "porcentaje" && (data.valor < 0 || data.valor > 100)) {
    ctx.addIssue({
      code: "custom",
      path: ["valor"],
      message: "Para 'porcentaje', el valor debe estar entre 0 y 100.",
    });
  }
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

    // 🔔 Enviar notificación a todos los clientes sobre la nueva promoción
    try {
      // Obtener información del comercio
      const comercioDoc = await db.collection("comercios").doc(data.comercio_id).get();
      const comercioNombre = comercioDoc.data()?.nombre || 'Un salón';

      await sendPushNotificationByRole(
        'cliente',
        {
          title: '🎉 Nueva Promoción Disponible',
          body: `${comercioNombre} tiene una nueva oferta en ${data.servicio_nombre}. ¡Aprovecha!`,
        },
        {
          type: 'nueva_promocion',
          entityId: docRef.id,
        }
      );
      console.log(`✅ Notificación de nueva promoción enviada a todos los clientes`);
    } catch (notifError) {
      console.error('⚠️ Error enviando notificaciones de promoción:', notifError);
    }

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
    
    console.log(`📊 Total promociones en Firestore: ${promociones.length}`);
    if (promociones.length > 0) {
      console.log(`📊 Primera promoción:`, JSON.stringify(promociones[0]));
    }
    
    res.json(promociones);
    return;
  } catch (error: any) {
    console.error('❌ Error obteniendo promociones:', error);
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