import { Request, Response } from "express";
import { db } from "../config/firebase";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";

const favoritoSchema = z.object({
  usuario_cliente_id: z.string().min(1),
  salon_id: z.string().min(1),
});

export const createFavorito = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = favoritoSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }

    const { usuario_cliente_id, salon_id } = parsed.data;

    // Verificar si ya existe
    const existing = await db.collection("favoritos")
      .where("usuario_cliente_id", "==", usuario_cliente_id)
      .where("salon_id", "==", salon_id)
      .get();

    if (!existing.empty) {
      res.status(409).json({ error: "Este salón ya está en favoritos" });
      return;
    }

    const favRef = await db.collection("favoritos").add({
      usuario_cliente_id,
      salon_id,
      fecha_creacion: FieldValue.serverTimestamp(),
    });

    res.status(201).json({ id: favRef.id, usuario_cliente_id, salon_id });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const getFavoritos = async (req: Request, res: Response): Promise<void> => {
  try {
    const { clienteId } = req.query;
    let query = db.collection("favoritos");

    if (clienteId) {
      query = query.where("usuario_cliente_id", "==", clienteId) as any;
    }

    const snapshot = await query.get();
    const favoritos = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(favoritos);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const getFavoritoById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection("favoritos").doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Favorito no encontrado" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};

export const updateFavorito = async (req: Request, res: Response): Promise<void> => {
  res.status(405).json({ error: "Método no permitido para favoritos" });
};

export const deleteFavorito = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("favoritos").doc(req.params.id).delete();
    res.json({ message: "Favorito eliminado" });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
};