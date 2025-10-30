import { Request, Response } from "express";
import { db } from "../config/firebase";
import { Favorito } from "../modelos/favorito.model";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";

// Schema robusto con coerción de tipos
const favoritoSchema = z.object({
  usuario_cliente_id: z.string().min(1),
  usuario_salon_id: z.string().min(1),
  fecha: z.coerce.date().optional(), // acepta ISO o string
});

// Crear favorito
export const createFavorito = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = favoritoSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    const data = parsed.data;

    const payload = {
      ...data,
      fecha: data.fecha ?? FieldValue.serverTimestamp(),
      fecha_creacion: FieldValue.serverTimestamp(),
      fecha_actualizacion: FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection("favoritos").add(payload);
    res.status(201).json({ id: docRef.id, ...data });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener todos los favoritos
export const getFavoritos = async (_req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection("favoritos").get();
    const favoritos: Favorito[] = snapshot.docs.map(
      (doc) => ({ id: doc.id, ...doc.data() } as Favorito)
    );
    res.json(favoritos);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener favorito por ID
export const getFavoritoById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection("favoritos").doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Favorito no encontrado" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() } as Favorito);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Actualizar favorito
export const updateFavorito = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = favoritoSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }
    const data = parsed.data;
    await db
      .collection("favoritos")
      .doc(req.params.id)
      .update({ ...data, fecha_actualizacion: FieldValue.serverTimestamp() });
    res.json({ message: "Favorito actualizado" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Eliminar favorito
export const deleteFavorito = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("favoritos").doc(req.params.id).delete();
    res.json({ message: "Favorito eliminado" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};