import { Request, Response } from "express";
import { db } from "../config/firebase";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";

// Esquema de validación para las citas
const citaSchema = z.object({
  usuario_cliente_id: z.string().min(1),
  comercio_id: z.string().min(1), // ✅ Requerido
  servicio_id: z.string().min(1),
  servicio_nombre: z.string().optional(),
  fecha_hora: z.string().min(1),
  duracion_min: z.number().int().min(1),
  precio: z.number().min(0),
  estado: z.enum(["pendiente", "confirmada", "completada", "cancelada"]).optional(),
  estado_pago: z.enum(["pendiente", "pagado"]).optional(),
  notas: z.string().optional(),
});

// Crear cita
export const createCita = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = citaSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos inválidos", details: parsed.error.issues });
      return;
    }

    const data = parsed.data;

    // ✅ CAMBIO: Verificar disponibilidad del horario por comercio_id
    const existingCita = await db.collection("citas")
      .where("comercio_id", "==", data.comercio_id)
      .where("fecha_hora", "==", data.fecha_hora)
      .where("estado", "in", ["pendiente", "confirmada"])
      .get();

    if (!existingCita.empty) {
      res.status(409).json({ error: "Este horario ya está ocupado" });
      return;
    }

    const citaRef = await db.collection("citas").add({
      ...data,
      estado: data.estado ?? "pendiente",
      estado_pago: data.estado_pago ?? "pendiente",
      fecha_creacion: FieldValue.serverTimestamp(),
    });

    res.status(201).json({ id: citaRef.id, ...data });
  } catch (error: any) {
    console.error("Error creando cita:", error);
    res.status(500).json({ error: error.message });
  }
};

// Obtener todas las citas (con filtros opcionales)
export const getCitas = async (req: Request, res: Response): Promise<void> => {
  try {
    const { clienteId, salonId } = req.query;
    let query = db.collection("citas");

    // Filtrar por cliente
    if (clienteId) {
      query = query.where("usuario_cliente_id", "==", clienteId) as any;
    }
    // Filtrar por salón
    if (salonId) {
      query = query.where("usuario_salon_id", "==", salonId) as any;
    }

    const snapshot = await query.get();
    const citas = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(citas);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
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
    res.json({ id: doc.id, ...doc.data() });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Actualizar cita
export const updateCita = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = citaSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos inválidos", details: parsed.error.issues });
      return;
    }

    await db.collection("citas").doc(req.params.id).update({
      ...parsed.data,
      fecha_actualizacion: FieldValue.serverTimestamp(),
    });

    res.json({ message: "Cita actualizada" });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// Eliminar cita
export const deleteCita = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("citas").doc(req.params.id).delete();
    res.json({ message: "Cita eliminada" });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

// ✅ NUEVO: Obtener citas por usuario (cliente o salón)
export const getCitasByUsuario = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    
    console.log(`🔍 Buscando citas para usuario: ${userId}`);
    
    // Buscar citas donde el usuario sea cliente
    const citasClienteSnapshot = await db.collection("citas")
      .where("usuario_cliente_id", "==", userId)
      .get();
    
    // ✅ CAMBIO: Buscar citas donde el usuario sea dueño del comercio
    const comerciosSnapshot = await db.collection("comercios")
      .where("uid_negocio", "==", userId)
      .get();
    
    const comercioIds = comerciosSnapshot.docs.map(doc => doc.id);
    
    let citasComercio: any[] = [];
    
    // Si el usuario tiene comercios, buscar citas de esos comercios
    if (comercioIds.length > 0) {
      // Firestore limita 'in' a 10 elementos, así que hacemos queries por lotes
      const batchSize = 10;
      for (let i = 0; i < comercioIds.length; i += batchSize) {
        const batch = comercioIds.slice(i, i + batchSize);
        const citasSnapshot = await db.collection("citas")
          .where("comercio_id", "in", batch)
          .get();
        
        citasComercio.push(...citasSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      }
    }
    
    // Combinar ambas búsquedas sin duplicados
    const citasMap = new Map();
    
    citasClienteSnapshot.forEach(doc => {
      citasMap.set(doc.id, { id: doc.id, ...doc.data() });
    });
    
    citasComercio.forEach(cita => {
      if (!citasMap.has(cita.id)) {
        citasMap.set(cita.id, cita);
      }
    });
    
    const citas = Array.from(citasMap.values());
    
    console.log(`✅ ${citas.length} citas encontradas para usuario ${userId}`);
    
    if (citas.length === 0) {
      res.status(404).json({ mensaje: "No se encontraron citas para este usuario" });
      return;
    }
    
    res.json(citas);
  } catch (error: any) {
    console.error("❌ Error obteniendo citas del usuario:", error);
    res.status(500).json({ error: error.message });
  }
};