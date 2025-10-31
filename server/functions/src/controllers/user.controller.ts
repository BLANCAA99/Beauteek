import { Request, Response } from "express";
import { db } from "../config/firebase";
import { Usuario } from "../modelos/usuario.model";
import { z } from "zod";
import bcrypt from "bcrypt";

// 🔹 Esquema de validación con Zod
export const usuarioSchema = z.object({
  uid: z.string().min(1), // <-- AÑADIR uid al esquema
  nombre_completo: z.string().min(1),
  email: z.string().email(),
  password: z.string().min(6),
  telefono: z.string().optional(),
  rol: z.string().optional(),
  foto_url: z.string().url().optional(),
  direccion: z.string().optional(),
  fecha_nacimiento: z.string().refine((dob) => {
    const today = new Date();
    const birthDate = new Date(dob);
    let age = today.getFullYear() - birthDate.getFullYear();
    const m = today.getMonth() - birthDate.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
    return age >= 18;
  }, { message: "Debes ser mayor de 18 años para registrarte." }),
  genero: z.string().optional(),
  geo_lat: z.number().optional(),
  geo_lng: z.number().optional(),
  estado: z.string().optional(),
  fecha_creacion: z.string().optional(),
});

// --- AÑADIDO: Esquema para la actualización del perfil ---
// Este esquema es más flexible y solo incluye los campos que el usuario puede editar.
const updateUsuarioSchema = z.object({
  nombre_completo: z.string().min(1).optional(),
  telefono: z.string().optional(),
  direccion: z.string().optional(),
  foto_url: z.string().url().optional().or(z.literal('')), // Permite URL o string vacío
  fecha_nacimiento: z.string().optional(),
  genero: z.string().optional(),
});


// 🔹 Crear usuario sin hash (por ejemplo, para seeds o pruebas)
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
    console.log("[createUser] Datos validados:", data);

    await db.collection("usuarios").doc(uid).set({
      ...data,
      fecha_creacion: new Date().toISOString(),
    });

    console.log("[createUser] Usuario creado en Firestore con ID (UID):", uid);
    res.status(201).json({ id: uid, ...data });
  } catch (error: any) {
    console.error("[createUser] Error al crear usuario:", error);
    res.status(500).json({ error: error.message });
  }
};
// 🔹 Registro de usuario (con hash de contraseña)
export const registerUser = async (req: Request, res: Response): Promise<void> => {
  console.log("[registerUser] Body recibido:", req.body);
  try {
    const parsed = usuarioSchema.safeParse(req.body);
    if (!parsed.success) {
      console.log("[registerUser] Error de validación Zod:", parsed.error.issues);
      res.status(400).json({ error: parsed.error.issues });
      return;
    }

    const { password, ...rest } = parsed.data;
    console.log("[registerUser] Hasheando contraseña...");
    const hashedPassword = await bcrypt.hash(password, 10);

    const userData = { ...rest, password: hashedPassword, fecha_creacion: new Date().toISOString() };
    console.log("[registerUser] Datos listos para insertar:", userData);

    const docRef = await db.collection("usuarios").add(userData);

    console.log("[registerUser] Usuario registrado con ID:", docRef.id);
    res.status(201).json({ id: docRef.id, ...userData });
  } catch (error: any) {
    console.error("[registerUser] Error al registrar usuario:", error);
    res.status(500).json({ error: error.message });
  }
};


// 🔹 Obtener todos los usuarios
export const getUsers = async (_req: Request, res: Response): Promise<void> => {
  console.log("[getUsers] Solicitando lista de usuarios...");
  try {
    const snapshot = await db.collection("usuarios").get();
    console.log(`[getUsers] ${snapshot.size} usuarios encontrados.`);
    const users: Usuario[] = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Usuario));
    res.json(users);
  } catch (error: any) {
    console.error("[getUsers] Error al obtener usuarios:", error);
    res.status(500).json({ error: error.message });
  }
};


// 🔹 Obtener usuario por ID
export const getUserById = async (req: Request, res: Response): Promise<void> => {
  console.log("[getUserById] ID recibido:", req.params.id);
  try {
    // CORRECCIÓN: Usar la colección 'usuarios' (plural)
    const doc = await db.collection("usuarios").doc(req.params.id).get();
    if (!doc.exists) {
      console.log("[getUserById] Usuario no encontrado en la colección 'usuarios'.");
      res.status(404).json({ error: "Usuario no encontrado" });
      return;
    }
    console.log("[getUserById] Usuario encontrado:", doc.data());
    res.json({ id: doc.id, ...doc.data() } as Usuario);
  } catch (error: any) {
    console.error("[getUserById] Error al obtener usuario:", error);
    res.status(500).json({ error: error.message });
  }
};


// 🔹 Obtener usuario por UID de Firebase Auth
export const getUserByUid = async (req: Request, res: Response): Promise<void> => {
  const { uid } = req.params;
  console.log(`[getUserByUid] Buscando usuario con UID: ${uid}`);
  try {
    const snapshot = await db.collection("usuarios").where("uid", "==", uid).limit(1).get();

    if (snapshot.empty) {
      console.log(`[getUserByUid] Usuario con UID ${uid} no encontrado.`);
      res.status(404).json({ error: "Usuario no encontrado" });
      return; // Este return es correcto porque solo termina la función
    }

    const userDoc = snapshot.docs[0];
    console.log("[getUserByUid] Usuario encontrado:", userDoc.data());
    res.json({ id: userDoc.id, ...userDoc.data() }); // Se quita el return de aquí
  } catch (error: any) {
    console.error("[getUserByUid] Error al obtener usuario por UID:", error);
    res.status(500).json({ error: error.message }); // Se quita el return de aquí
  }
};


// 🔹 Actualizar usuario
export const updateUser = async (req: Request, res: Response): Promise<void> => {
  const userId = req.params.uid; // <-- CAMBIO: de 'id' a 'uid'
  console.log("[updateUser] UID:", userId, "Body:", req.body);

  try {
    // Usamos el nuevo esquema de actualización
    const parsed = updateUsuarioSchema.safeParse(req.body);
    if (!parsed.success) {
      console.log("[updateUser] Error de validación Zod:", parsed.error.issues);
      res.status(400).json({ error: parsed.error.issues });
      return;
    }

    const dataToUpdate = parsed.data;

    // Limpiar claves con valores undefined para no sobrescribir con nada
    Object.keys(dataToUpdate).forEach(key => {
      if ((dataToUpdate as any)[key] === undefined) {
        delete (dataToUpdate as any)[key];
      }
    });

    if (Object.keys(dataToUpdate).length === 0) {
      res.status(400).json({ error: "No hay datos para actualizar." });
      return;
    }

    await db.collection("usuarios").doc(userId).update(dataToUpdate);
    console.log("[updateUser] Usuario actualizado correctamente.");

    // Después de actualizar, obtenemos y devolvemos el documento actualizado
    const updatedDoc = await db.collection("usuarios").doc(userId).get();
    if (!updatedDoc.exists) {
      res.status(404).json({ error: "Usuario no encontrado después de actualizar." });
      return;
    }

    res.status(200).json({ id: updatedDoc.id, ...updatedDoc.data() });

  } catch (error: any) {
    console.error("[updateUser] Error al actualizar usuario:", error);
    res.status(500).json({ error: error.message });
  }
};


// 🔹 Eliminar usuario
export const deleteUser = async (req: Request, res: Response): Promise<void> => {
  console.log("[deleteUser] UID recibido:", req.params.uid);
  try {
    await db.collection("usuarios").doc(req.params.uid).delete();
    console.log("[deleteUser] Usuario eliminado correctamente.");
    res.json({ message: "Usuario eliminado" });
  } catch (error: any) {
    console.error("[deleteUser] Error al eliminar usuario:", error);
    res.status(500).json({ error: error.message });
  }
};