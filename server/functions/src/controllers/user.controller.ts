import { Request, Response } from "express";
import { db, admin } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";
import { Usuario } from "../modelos/usuario.model";
import { z } from "zod";
import * as nodemailer from "nodemailer";

/* =========================
   Esquemas Zod
   ========================= */

// Perfil base para crear (SIN password). Aplica a clientes y salones.
export const usuarioSchema = z.object({
  uid: z.string().min(1),
  nombre_completo: z.string().min(1),
  email: z.string().email(),
  telefono: z.string().optional(),
  rol: z.enum(["cliente", "salon"]).optional(),

  // Perfil general
  foto_url: z.string().optional(),
  direccion: z.string().optional(),
  fecha_nacimiento: z.string().optional(),
  genero: z.string().optional(),
  estado: z.string().optional(),
  pais: z.string().optional(),

  // Campos de negocio (para salones)
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

    // Verificar si ya existe
    const docRef = db.collection("usuarios").doc(uid);
    const existing = await docRef.get();
    
    if (existing.exists) {
      console.log("[createUser] Usuario ya existe, retornando datos existentes");
      // Retornar usuario existente (útil para Google Sign In)
      res.status(200).json({ id: uid, ...existing.data() });
      return;
    }

    // Crear nuevo usuario
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
   ========================= */

const registerUserSchema = z.object({
  nombre_completo: z.string().min(1, "El nombre completo es requerido."),
  email: z.string().email("El formato del email es inválido."),
  password: z.string().min(6, "La contraseña debe tener al menos 6 caracteres."),
  telefono: z.string().min(8, "El teléfono debe tener al menos 8 dígitos."),
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
  pais: z.string().optional(),
  estado: z.string().optional(),
});

export const registerUserComplete = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = registerUserSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos de entrada inválidos", details: parsed.error.issues });
      return;
    }

    const { email, password } = parsed.data;

    // Crear usuario en Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
    });

    const newUid = userRecord.uid;

    // Asignar rol de "cliente"
    await admin.auth().setCustomUserClaims(newUid, { role: "cliente" });

    // Guardar perfil completo en Firestore (sin la contraseña)
    const { password: _password, ...userDataForFirestore } = parsed.data;
    const userPayload = {
      ...userDataForFirestore,
      uid: newUid,
      rol: "cliente",
      fecha_creacion: FieldValue.serverTimestamp(),
      foto_url: "pendiente",
    };

    await db.collection("usuarios").doc(newUid).set(userPayload);

    res.status(201).json({
      message: "Usuario registrado exitosamente.",
      uid: newUid,
    });
  } catch (error: any) {
    console.error("Error en registerUserComplete:", error);
    res.status(500).json({
      message: "Error interno del servidor.",
      error: error.message,
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
   ========================= */

export const setupSalon = async (req: Request, res: Response): Promise<void> => {
  try {
    const { uid, nombre_salon, direccion } = req.body;

    if (!uid || !nombre_salon || !direccion) {
      res.status(400).json({ error: "Faltan campos requeridos para configurar el salón." });
      return;
    }

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

// --- Listar salones cercanos ---
export const getSalonsNearby = async (req: Request, res: Response): Promise<void> => {
  try {
    const lat = parseFloat(req.query.lat as string);
    const lng = parseFloat(req.query.lng as string);
    const radius = parseInt(req.query.radius as string, 10) || 5000;

    if (isNaN(lat) || isNaN(lng)) {
      res.status(400).json({ error: "Latitud y longitud son requeridas." });
      return;
    }

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

// DEPRECADO
export const registerSalonComplete = async (req: Request, res: Response): Promise<void> => {
  res.status(410).json({
    message: "Este endpoint está deprecado. Usa /api/comercios/register-salon-step1, step2 y step3"
  });
};

// Actualizar FCM token del usuario
export const updateFCMToken = async (req: Request, res: Response): Promise<void> => {
  try {
    // req.user viene del middleware de autenticación
    const uid = (req as any).user?.uid;
    
    if (!uid) {
      res.status(401).json({ error: "No autenticado" });
      return;
    }

    const { fcm_token, platform } = req.body;

    if (!fcm_token) {
      res.status(400).json({ error: "fcm_token es requerido" });
      return;
    }

    await db.collection("usuarios").doc(uid).update({
      fcm_token,
      platform: platform || 'unknown',
      fcm_token_updated_at: FieldValue.serverTimestamp(),
    });

    console.log(`[updateFCMToken] Token FCM actualizado para usuario ${uid}`);
    res.status(200).json({ message: "Token FCM actualizado" });
  } catch (error: any) {
    console.error("[updateFCMToken] Error:", error);
    res.status(500).json({ error: error.message });
  }
};

// Eliminar FCM token del usuario (logout)
export const deleteFCMToken = async (req: Request, res: Response): Promise<void> => {
  try {
    const uid = (req as any).user?.uid;
    
    if (!uid) {
      res.status(401).json({ error: "No autenticado" });
      return;
    }

    await db.collection("usuarios").doc(uid).update({
      fcm_token: FieldValue.delete(),
      platform: FieldValue.delete(),
      fcm_token_updated_at: FieldValue.delete(),
    });

    console.log(`[deleteFCMToken] Token FCM eliminado para usuario ${uid}`);
    res.status(200).json({ message: "Token FCM eliminado" });
  } catch (error: any) {
    console.error("[deleteFCMToken] Error:", error);
    res.status(500).json({ error: error.message });
  }
};

// Configurar transporter de email
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD,
  },
});

// Almacenamiento temporal de códigos de verificación
const verificationCodes = new Map<string, { code: string; expiresAt: number }>();

// Generar código de 6 dígitos
function generateVerificationCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Enviar código de verificación al email
export const sendVerificationCode = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email } = req.body;

    if (!email || !z.string().email().safeParse(email).success) {
      res.status(400).json({ error: "Email inválido" });
      return;
    }

    const code = generateVerificationCode();
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutos

    verificationCodes.set(email, { code, expiresAt });

    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'Código de verificación - Beauteek',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #EA963A;">Verifica tu correo electrónico</h2>
          <p>Tu código de verificación para Beauteek es:</p>
          <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0;">
            <h1 style="color: #EA963A; letter-spacing: 8px; margin: 0;">${code}</h1>
          </div>
          <p>Este código expirará en 10 minutos.</p>
          <p>Si no solicitaste este código, puedes ignorar este correo.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
          <p style="color: #888; font-size: 12px;">Beauteek - Beauty Salon Booking App</p>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    
    console.log(`[sendVerificationCode] Código enviado a ${email}`);
    res.status(200).json({ message: "Código de verificación enviado" });
  } catch (error: any) {
    console.error("[sendVerificationCode] Error:", error);
    res.status(500).json({ error: "Error al enviar código de verificación" });
  }
};

// Verificar código ingresado por el usuario
export const verifyCode = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      res.status(400).json({ error: "Email y código son requeridos" });
      return;
    }

    const storedData = verificationCodes.get(email);

    if (!storedData) {
      res.status(400).json({ error: "Código no encontrado o expirado" });
      return;
    }

    if (Date.now() > storedData.expiresAt) {
      verificationCodes.delete(email);
      res.status(400).json({ error: "El código ha expirado" });
      return;
    }

    if (storedData.code !== code) {
      res.status(400).json({ error: "Código incorrecto" });
      return;
    }

    verificationCodes.delete(email);
    
    console.log(`[verifyCode] Código verificado correctamente para ${email}`);
    res.status(200).json({ message: "Código verificado correctamente", verified: true });
  } catch (error: any) {
    console.error("[verifyCode] Error:", error);
    res.status(500).json({ error: "Error al verificar código" });
  }
};