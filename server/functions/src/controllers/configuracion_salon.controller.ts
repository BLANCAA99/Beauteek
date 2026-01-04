import { Request, Response } from "express";
import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";

export const getConfiguracionSalon = async (req: Request, res: Response): Promise<void> => {
  try {
    const { comercioId } = req.params;

    if (!comercioId) {
      res.status(400).json({ error: "ID de comercio requerido" });
      return;
    }

    const configDoc = await db.collection("configuracion_salon").doc(comercioId).get();

    if (!configDoc.exists) {
      res.status(200).json({
        notificar_reservas: true,
      });
      return;
    }

    const data = configDoc.data()!;
    res.status(200).json({
      notificar_reservas: data.notificar_reservas ?? true,
      fecha_actualizacion: data.fecha_actualizacion,
    });
  } catch (error) {
    console.error("Error al obtener configuración:", error);
    res.status(500).json({ error: "Error al obtener configuración" });
  }
};

export const updateConfiguracionSalon = async (req: Request, res: Response): Promise<void> => {
  try {
    const { comercioId } = req.params;
    const { notificar_reservas } = req.body;

    if (!comercioId) {
      res.status(400).json({ error: "ID de comercio requerido" });
      return;
    }

    await db.collection("configuracion_salon").doc(comercioId).set({
      notificar_reservas: notificar_reservas ?? true,
      fecha_actualizacion: FieldValue.serverTimestamp(),
    }, { merge: true });

    res.status(200).json({ 
      message: "Configuración actualizada correctamente",
      notificar_reservas
    });
  } catch (error) {
    console.error("Error al actualizar configuración:", error);
    res.status(500).json({ error: "Error al actualizar configuración" });
  }
};
