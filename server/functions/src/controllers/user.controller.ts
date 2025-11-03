import { Request, Response } from "express";
import { db, admin } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";
import { Usuario } from "../modelos/usuario.model";
import { z } from "zod";

/* =========================
   Esquemas Zod
   ========================= */

// Perfil base para crear (SIN password). Aplica a clientes y salones.
// Si rol = 'salon', los campos de negocio son OPCIONALES (puedes exigirlos desde el formulario).
export const usuarioSchema = z.object({
  uid: z.string().min(1),
  nombre_completo: z.string().min(1),
  email: z.string().email(),
  telefono: z.string().optional(),
  rol: z.enum(["cliente", "salon"]).optional(),

  // Perfil general
  foto_url: z.string().url().optional(),
  direccion: z.string().optional(),
  fecha_nacimiento: z
    .string()
    .refine((dob) => {
      // Nota: Si quieres permitir crear sin DOB, déjalo como optional(). Si lo envían, validamos 18+
      const today = new Date();
      const birthDate = new Date(dob);
      let age = today.getFullYear() - birthDate.getFullYear();
      const m = today.getMonth() - birthDate.getMonth();
      if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) age--;
      return age >= 18;
    }, { message: "Debes ser mayor de 18 años para registrarte." })
    .optional(),
  genero: z.string().optional(),
  estado: z.string().optional(),

  // Campos de negocio (para salones) - SOLO información administrativa
  rtn: z.string().regex(/^\d{14}$/, "RTN debe tener 14 dígitos").optional(),
  razon_social: z.string().min(2).optional(),
  banco_id: z.string().optional(),
  cuenta_bancaria: z.string().regex(/^\d{10,20}$/, "Cuenta bancaria inválida").optional(),
  tipo_cuenta: z.enum(["ahorro", "corriente"]).optional(),
  verificacion_bancaria_status: z.enum(["pending", "verified", "rejected"]).optional(),

  fecha_creacion: z.any().optional(),
});

// Para updates (todo opcional). No dejamos cambiar uid/email/rol desde aquí por seguridad.
const updateUsuarioSchema = usuarioSchema.partial().omit({ uid: true, email: true, rol: true });

/* =========================
   Controladores
   ========================= */

// 🔹 Crear usuario (perfil) en Firestore SIN password
// Se usa cuando ya creaste la cuenta en Firebase Auth (email/pass o Google) desde el frontend.
// Envías uid, email y los demás datos de perfil (y si es salón, sus extras).
export const createUser = async (req: Request, res: Response): Promise<void> => {
  console.log("[createUser] Body recibido:", req.body);
  try {
    const parsed = usuarioSchema.safeParse(req.body);
    if (!parsed.success) {
      console.log("[createUser] Error de validación Zod:", parsed.error.issues);
      res.status(400).json({ error: parsed.error.issues });
      return;
    }

    const { uid, ...data } = parsed.data;

    // Evitar overwrite accidental si ya existe
    const docRef = db.collection("usuarios").doc(uid);
    const existing = await docRef.get();
    if (existing.exists) {
      res.status(409).json({ error: "El perfil ya existe para este UID." });
      return;
    }

    await docRef.set({
      uid,
      ...data,
      verificacion_bancaria_status: data.verificacion_bancaria_status ?? "pending",
      fecha_creacion: FieldValue.serverTimestamp(),
    });

    console.log("[createUser] Usuario creado en Firestore con ID (UID):", uid);
    res.status(201).json({ id: uid, ...data });
  } catch (error: any) {
    console.error("[createUser] Error al crear usuario:", error);
    res.status(500).json({ error: error.message });
  }
};

// 🔹 Obtener todos los usuarios
export const getUsers = async (_req: Request, res: Response): Promise<void> => {
  console.log("[getUsers] Solicitando lista de usuarios...");
  try {
    const snapshot = await db.collection("usuarios").get();
    console.log(`[getUsers] ${snapshot.size} usuarios encontrados.`);
    const users: Usuario[] = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() } as Usuario));
    res.json(users);
  } catch (error: any) {
    console.error("[getUsers] Error al obtener usuarios:", error);
    res.status(500).json({ error: error.message });
  }
};

// 🔹 Obtener usuario por UID (doc(uid) con fallback a where(uid))
export const getUserByUid = async (req: Request, res: Response): Promise<void> => {
  const { uid } = req.params;
  console.log(`[getUserByUid] Buscando usuario con UID: ${uid}`);
  try {
    // 1) Intento directo por doc id = uid
    const doc = await db.collection("usuarios").doc(uid).get();
    if (doc.exists) {
      console.log("[getUserByUid] Usuario encontrado por doc(uid).");
      res.json({ id: doc.id, ...doc.data() });
      return;
    }

    // 2) Fallback para compatibilidad con docs viejos
    const snapshot = await db.collection("usuarios").where("uid", "==", uid).limit(1).get();
    if (snapshot.empty) {
      console.log(`[getUserByUid] Usuario con UID ${uid} no encontrado.`);
      res.status(404).json({ error: "Usuario no encontrado" });
      return;
    }

    const userDoc = snapshot.docs[0];
    console.log("[getUserByUid] Usuario encontrado por where(uid).");
    res.json({ id: userDoc.id, ...userDoc.data() });
  } catch (error: any) {
    console.error("[getUserByUid] Error al obtener usuario por UID:", error);
    res.status(500).json({ error: error.message });
  }
};

// 🔹 Actualizar usuario (solo campos permitidos)
// No permite cambiar uid/email/rol desde este endpoint público.
export const updateUser = async (req: Request, res: Response): Promise<void> => {
  const { uid } = req.params;

  try {
    const parsed = updateUsuarioSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }

    const dataToUpdate = parsed.data;
    if (Object.keys(dataToUpdate).length === 0) {
      res.status(400).json({ error: "No hay datos para actualizar." });
      return;
    }

    await db.collection("usuarios").doc(uid).update({
      ...dataToUpdate,
      fecha_actualizacion: FieldValue.serverTimestamp(),
    });

    console.log("[updateUser] Usuario actualizado correctamente.");
    res.json({ message: "Usuario actualizado" });
  } catch (error: any) {
    console.error("[updateUser] Error al actualizar usuario:", error);
    if (error?.code === 5 /* NOT_FOUND */) {
      res.status(404).json({ error: "Usuario no encontrado." });
      return;
    }
    res.status(500).json({ error: error.message });
  }
};

/* =========================
   Registro completo de Usuario (Cliente)
   Crea el usuario en Firebase Auth y el perfil en Firestore desde el backend.
   ========================= */

// 1. Define un esquema más estricto SOLO para el registro de clientes.
const registerUserSchema = z.object({
  nombre_completo: z.string().min(1, "El nombre completo es requerido."),
  email: z.string().email("El formato del email es inválido."),
  password: z.string().min(6, "La contraseña debe tener al menos 6 caracteres."),
  telefono: z.string().min(8, "El teléfono debe tener al menos 8 dígitos."),

  // Estos campos son obligatorios en el registro completo
  direccion: z.string().min(5, "La dirección es requerida."),
  fecha_nacimiento: z.string().min(1, "La fecha de nacimiento es requerida.").refine((dob) => {
      const today = new Date();
      const birthDate = new Date(dob);
      let age = today.getFullYear() - birthDate.getFullYear();
      const m = today.getMonth() - birthDate.getMonth();
      if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) age--;
      return age >= 18;
    }, { message: "Debes ser mayor de 18 años para registrarte." }),
  genero: z.string().min(1, "El género es requerido."),

  // Campos opcionales
  estado: z.string().optional(),
});


export const registerUserComplete = async (req: Request, res: Response): Promise<void> => {
  try {
    // 1. Validar los datos de entrada
    const parsed = registerUserSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos de entrada inválidos", details: parsed.error.issues });
      return;
    }

    const { email, password } = parsed.data;

    // 2. Crear usuario en Firebase Authentication SÓLO con email y password
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      // Se han eliminado displayName y phoneNumber de aquí
    });

    const newUid = userRecord.uid;

    // 3. Asignar rol de "cliente"
    await admin.auth().setCustomUserClaims(newUid, { role: "cliente" });

    // 4. Guardar perfil completo en Firestore (sin la contraseña)
    const { password: _password, ...userDataForFirestore } = parsed.data;
    const userPayload = {
      ...userDataForFirestore,
      uid: newUid,
      rol: "cliente",
      fecha_creacion: FieldValue.serverTimestamp(),
      foto_url: "pendiente", // <-- AÑADE ESTA LÍNEA
    };

    await db.collection("usuarios").doc(newUid).set(userPayload);

    // 5. Enviar respuesta exitosa
    res.status(201).json({
      message: "Usuario registrado exitosamente.",
      uid: newUid,
    });
  } catch (error: any) {
    console.error("Error en registerUserComplete:", error);
    res.status(500).json({
      message: "Error interno del servidor.",
      error: error.message, // Devuelve el mensaje de error real para depuración
    });
  }
};

// 🔹 Eliminar usuario
export const deleteUser = async (req: Request, res: Response): Promise<void> => {
  console.log("[deleteUser] ID recibido:", req.params.id);
  try {
    await db.collection("usuarios").doc(req.params.id).delete();
    console.log("[deleteUser] Usuario eliminado correctamente.");
    res.json({ message: "Usuario eliminado" });
  } catch (error: any) {
    console.error("[deleteUser] Error al eliminar usuario:", error);
    res.status(500).json({ error: error.message });
  }
};

/* =========================
   Helpers de salón - DEPRECADOS
   Estos métodos ya no son necesarios con el nuevo flujo de registro por pasos
   ========================= */

// --- DEPRECADO: Usar registerSalonStep1, Step2, Step3 en comercio.controller ---
export const setupSalon = async (req: Request, res: Response): Promise<void> => {
  try {
    const { uid, nombre_salon, direccion } = req.body;

    if (!uid || !nombre_salon || !direccion) {
      res.status(400).json({ error: "Faltan campos requeridos para configurar el salón." });
      return;
    }

    // Solo actualizamos información básica, la geo va en comercios
    await db.collection("usuarios").doc(uid).update({
      rol: "salon",
      nombre_completo: nombre_salon,
      direccion,
      fecha_actualizacion: FieldValue.serverTimestamp(),
    });

    res.status(200).json({ message: "Salón configurado exitosamente." });
  } catch (error: any) {
    res.status(500).json({ error: `Error al configurar el salón: ${error.message}` });
  }
};

// --- Utilidad Haversine ---
const getDistanceInMeters = (lat1: number, lon1: number, lat2: number, lon2: number): number => {
  const R = 6371e3;
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
};

// --- Listar salones cercanos - AHORA USA LA COLECCIÓN COMERCIOS ---
export const getSalonsNearby = async (req: Request, res: Response): Promise<void> => {
  try {
    const lat = parseFloat(req.query.lat as string);
    const lng = parseFloat(req.query.lng as string);
    const radius = parseInt(req.query.radius as string, 10) || 5000;

    if (isNaN(lat) || isNaN(lng)) {
      res.status(400).json({ error: "Latitud y longitud son requeridas." });
      return;
    }

    // Ahora buscamos en la colección comercios que tiene la geolocalización
    const comerciosSnapshot = await db
      .collection("comercios")
      .where("estado", "==", "activo")
      .get();

    const nearbySalons = comerciosSnapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((comercio: any) => {
        if (comercio.geo) {
          const distance = getDistanceInMeters(
            lat, 
            lng, 
            comercio.geo.latitude, 
            comercio.geo.longitude
          );
          return distance <= radius;
        }
        return false;
      });

    res.status(200).json(nearbySalons);
  } catch (error: any) {
    res.status(500).json({ error: `Error al buscar salones cercanos: ${error.message}` });
  }
};

/* =========================
   DEPRECADO: registerSalonComplete
   Usar en su lugar: registerSalonStep1, Step2, Step3 en comercio.controller
   ========================= */

export const registerSalonComplete = async (req: Request, res: Response): Promise<void> => {
  res.status(410).json({ 
    message: "Este endpoint está deprecado. Usa /api/comercios/register-salon-step1, step2 y step3" 
  });
};