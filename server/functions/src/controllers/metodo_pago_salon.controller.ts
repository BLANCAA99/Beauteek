import { Request, Response } from "express";
import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";

export const getMetodosPagoSalon = async (req: Request, res: Response): Promise<void> => {
  try {
    const { comercioId } = req.params;

    if (!comercioId) {
      res.status(400).json({ error: "ID de comercio requerido" });
      return;
    }

    const metodosDoc = await db.collection("metodos_pago_salon").doc(comercioId).get();

    if (!metodosDoc.exists) {
      res.status(200).json({
        acepta_tarjeta: true,
        acepta_transferencia: false,
        acepta_pago_local: true,
      });
      return;
    }

    const data = metodosDoc.data()!;
    res.status(200).json({
      acepta_tarjeta: data.acepta_tarjeta ?? true,
      acepta_transferencia: data.acepta_transferencia ?? false,
      acepta_pago_local: data.acepta_pago_local ?? true,
      fecha_actualizacion: data.fecha_actualizacion,
    });
  } catch (error) {
    console.error("Error al obtener métodos de pago:", error);
    res.status(500).json({ error: "Error al obtener métodos de pago" });
  }
};

export const updateMetodosPagoSalon = async (req: Request, res: Response): Promise<void> => {
  try {
    const { comercioId } = req.params;
    const { acepta_tarjeta, acepta_transferencia, acepta_pago_local } = req.body;

    if (!comercioId) {
      res.status(400).json({ error: "ID de comercio requerido" });
      return;
    }

    if (!acepta_tarjeta && !acepta_transferencia && !acepta_pago_local) {
      res.status(400).json({ error: "Debes activar al menos un método de pago" });
      return;
    }

    await db.collection("metodos_pago_salon").doc(comercioId).set({
      acepta_tarjeta: acepta_tarjeta ?? true,
      acepta_transferencia: acepta_transferencia ?? false,
      acepta_pago_local: acepta_pago_local ?? true,
      fecha_actualizacion: FieldValue.serverTimestamp(),
    }, { merge: true });

    res.status(200).json({ 
      message: "Métodos de pago actualizados correctamente",
      acepta_tarjeta,
      acepta_transferencia,
      acepta_pago_local
    });
  } catch (error) {
    console.error("Error al actualizar métodos de pago:", error);
    res.status(500).json({ error: "Error al actualizar métodos de pago" });
  }
};
