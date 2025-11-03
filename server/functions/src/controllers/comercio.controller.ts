import { Request, Response } from "express";
import { db, admin } from "../config/firebase";
import { FieldValue, GeoPoint } from "firebase-admin/firestore"; // Agregar GeoPoint aquí
import { Comercio } from "../modelos/comercio.model";
import { z } from "zod";

/* =========================
   PASO 1: Registro básico del salón
   ========================= */

const registerStep1Schema = z.object({
  email: z.string().email("Email inválido"),
  password: z.string().min(6, "La contraseña debe tener al menos 6 caracteres"),
  nombre: z.string().min(1, "El nombre del salón es requerido"),
  telefono: z.string().min(8, "El teléfono debe tener al menos 8 dígitos"),
});

export const registerSalonStep1 = async (req: Request, res: Response): Promise<void> => {
  try {
    // 1. Validar datos
    const parsed = registerStep1Schema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos inválidos", details: parsed.error.issues });
      return;
    }

    const { email, password, nombre, telefono } = parsed.data;

    // 2. Obtener UID del propietario (desde el token verificado por middleware)
    const uidPropietario = (req as any).user?.uid;
    if (!uidPropietario) {
      res.status(401).json({ error: "No autorizado" });
      return;
    }

    // 3. Crear usuario del salón en Firebase Auth
    const salonUserRecord = await admin.auth().createUser({
      email,
      password,
      displayName: nombre,
    });

    const uidNegocio = salonUserRecord.uid;

    // 4. Asignar rol 'salon' al usuario creado
    await admin.auth().setCustomUserClaims(uidNegocio, { role: "salon" });

    // 5. Crear documento en colección 'usuarios' para el salón
    await db.collection("usuarios").doc(uidNegocio).set({
      uid: uidNegocio,
      nombre_completo: nombre,
      email,
      telefono,
      rol: "salon",
      estado: "incompleto",
      fecha_creacion: FieldValue.serverTimestamp(),
    });

    // 6. Crear documento en colección 'comercios'
    const comercioRef = db.collection("comercios").doc();
    const comercioId = comercioRef.id;

    await comercioRef.set({
      id_documento: comercioId,
      uid_cliente_propietario: uidPropietario,
      uid_negocio: uidNegocio,
      nombre,
      telefono,
      email,
      estado: "paso1_completado",
      fecha_creacion: FieldValue.serverTimestamp(),
    });

    res.status(201).json({
      message: "Paso 1 completado: Salón creado exitosamente",
      comercioId,
      uidNegocio,
    });
  } catch (error: any) {
    console.error("Error en registerSalonStep1:", error);
    if (error.code === "auth/email-already-exists") {
      res.status(409).json({ error: "El email ya está registrado" });
      return;
    }
    res.status(500).json({ error: error.message });
  }
};

/* =========================
   PASO 2: Agregar dirección y ubicación
   ========================= */

const registerStep2Schema = z.object({
  comercioId: z.string().min(1),
  direccion: z.string().min(5, "La dirección debe tener al menos 5 caracteres"),
  geo: z.object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
  }),
});

export const registerSalonStep2 = async (req: Request, res: Response): Promise<void> => {
  try {
    // 1. Validar datos
    const parsed = registerStep2Schema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos inválidos", details: parsed.error.issues });
      return;
    }

    const { comercioId, direccion, geo } = parsed.data;

    // 2. Verificar que el comercio existe y pertenece al usuario
    const uidPropietario = (req as any).user?.uid;
    const comercioDoc = await db.collection("comercios").doc(comercioId).get();

    if (!comercioDoc.exists) {
      res.status(404).json({ error: "Comercio no encontrado" });
      return;
    }

    const comercioData = comercioDoc.data() as Comercio;
    if (comercioData.uid_cliente_propietario !== uidPropietario) {
      res.status(403).json({ error: "No tienes permiso para editar este comercio" });
      return;
    }

    // 3. Actualizar documento de comercio con dirección y geolocalización
    await db.collection("comercios").doc(comercioId).update({
      direccion,
      geo: new GeoPoint(geo.latitude, geo.longitude), // Usar GeoPoint importado
      estado: "paso2_completado",
      fecha_actualizacion: FieldValue.serverTimestamp(),
    });

    res.status(200).json({
      message: "Paso 2 completado: Dirección guardada exitosamente",
      comercioId,
    });
  } catch (error: any) {
    console.error("Error en registerSalonStep2:", error);
    res.status(500).json({ error: error.message });
  }
};

/* =========================
   PASO 3: Agregar servicios y horarios
   ========================= */

const registerStep3Schema = z.object({
  comercioId: z.string().min(1),
  horarios: z.array(
    z.object({
      dia_semana: z.number().int().min(0).max(6),
      hora_inicio: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
      hora_fin: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
      activo: z.boolean(),
    })
  ).min(1, "Debes agregar al menos un horario"),
  servicios: z.array(
    z.object({
      categoria_id: z.string().min(1),
      nombre: z.string().min(1),
      descripcion: z.string().optional(),
      duracion_min: z.number().int().min(1),
      precio: z.number().min(0),
      moneda: z.string().min(1),
      activo: z.boolean(),
    })
  ).min(1, "Debes agregar al menos un servicio"),
});

export const registerSalonStep3 = async (req: Request, res: Response): Promise<void> => {
  try {
    // 1. Validar datos
    const parsed = registerStep3Schema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos inválidos", details: parsed.error.issues });
      return;
    }

    const { comercioId, horarios, servicios } = parsed.data;

    // 2. Verificar que el comercio existe y pertenece al usuario
    const uidPropietario = (req as any).user?.uid;
    const comercioDoc = await db.collection("comercios").doc(comercioId).get();

    if (!comercioDoc.exists) {
      res.status(404).json({ error: "Comercio no encontrado" });
      return;
    }

    const comercioData = comercioDoc.data() as Comercio;
    if (comercioData.uid_cliente_propietario !== uidPropietario) {
      res.status(403).json({ error: "No tienes permiso para editar este comercio" });
      return;
    }

    const uidNegocio = comercioData.uid_negocio;

    // 3. Usar batch para operaciones atómicas
    const batch = db.batch();

    // 3.1 Crear horarios
    horarios.forEach((horario) => {
      const horarioRef = db.collection("horarios").doc();
      batch.set(horarioRef, {
        ...horario,
        usuario_id: uidNegocio,
        fecha_creacion: FieldValue.serverTimestamp(),
      });
    });

    // 3.2 Crear servicios
    servicios.forEach((servicio) => {
      const servicioRef = db.collection("servicios").doc();
      batch.set(servicioRef, {
        ...servicio,
        usuario_id: uidNegocio,
        fecha_creacion: FieldValue.serverTimestamp(),
      });
    });

    // 3.3 Actualizar estado del comercio a 'activo'
    const comercioRef = db.collection("comercios").doc(comercioId);
    batch.update(comercioRef, {
      estado: "activo",
      fecha_activacion: FieldValue.serverTimestamp(),
      fecha_actualizacion: FieldValue.serverTimestamp(),
    });

    // 3.4 Actualizar estado del usuario
    const usuarioRef = db.collection("usuarios").doc(uidNegocio);
    batch.update(usuarioRef, {
      estado: "activo",
      fecha_actualizacion: FieldValue.serverTimestamp(),
    });

    // 4. Ejecutar batch
    await batch.commit();

    res.status(200).json({
      message: "¡Registro completado! Tu salón está activo.",
      comercioId,
      uidNegocio,
    });
  } catch (error: any) {
    console.error("Error en registerSalonStep3:", error);
    res.status(500).json({ error: error.message });
  }
};

/* =========================
   CRUD estándar
   ========================= */

export const getComercios = async (req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection("comercios").get();
    const comercios: Comercio[] = snapshot.docs.map(
      (doc) => ({ id: doc.id, ...doc.data() } as Comercio)
    );
    res.json(comercios);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const getComercioById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection("comercios").doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Comercio no encontrado" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() } as Comercio);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const updateComercio = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("comercios").doc(req.params.id).update({
      ...req.body,
      fecha_actualizacion: FieldValue.serverTimestamp(),
    });
    res.json({ message: "Comercio actualizado" });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const deleteComercio = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("comercios").doc(req.params.id).delete();
    res.json({ message: "Comercio eliminado" });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};
