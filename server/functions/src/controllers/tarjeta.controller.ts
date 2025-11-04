import { Request, Response } from "express";
import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";
import { tarjetaSchema } from "../modelos/tarjeta.model";

// Validar tarjeta (simulado - algoritmo de Luhn)
function validarNumeroTarjeta(numero: string): boolean {
  let sum = 0;
  let isEven = false;

  for (let i = numero.length - 1; i >= 0; i--) {
    let digit = parseInt(numero[i]);

    if (isEven) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }

    sum += digit;
    isEven = !isEven;
  }

  return sum % 10 === 0;
}

// Validar fecha de expiración
function validarFechaExpiracion(fecha: string): boolean {
  const [mes, año] = fecha.split('/').map(Number);
  const now = new Date();
  const currentYear = now.getFullYear() % 100;
  const currentMonth = now.getMonth() + 1;

  if (año < currentYear) return false;
  if (año === currentYear && mes < currentMonth) return false;

  return true;
}

export const agregarTarjeta = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = tarjetaSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos inválidos", details: parsed.error.issues });
      return;
    }

    const { numero_tarjeta, nombre_titular, fecha_expiracion, cvv: _cvv, tipo, banco } = parsed.data;
    // El CVV solo se valida pero no se guarda (por seguridad)

    if (!validarNumeroTarjeta(numero_tarjeta)) {
      res.status(400).json({ error: "Número de tarjeta inválido" });
      return;
    }

    if (!validarFechaExpiracion(fecha_expiracion)) {
      res.status(400).json({ error: "La tarjeta está vencida o la fecha es inválida" });
      return;
    }

    const usuarioId = (req as any).user?.uid;
    if (!usuarioId) {
      res.status(401).json({ error: "No autorizado" });
      return;
    }

    const tarjetasExistentes = await db.collection("tarjetas_usuarios")
      .where("usuario_id", "==", usuarioId)
      .get();

    const esPrimera = tarjetasExistentes.empty;

    const tarjetaRef = db.collection("tarjetas_usuarios").doc();
    await tarjetaRef.set({
      id_documento: tarjetaRef.id,
      usuario_id: usuarioId,
      numero_tarjeta_ultimos4: numero_tarjeta.slice(-4),
      nombre_titular,
      fecha_expiracion,
      tipo,
      banco,
      activa: true,
      es_principal: esPrimera,
      verificada: true,
      fecha_creacion: FieldValue.serverTimestamp(),
    });

    res.status(201).json({
      message: "Tarjeta agregada exitosamente",
      tarjetaId: tarjetaRef.id,
      ultimos4: numero_tarjeta.slice(-4),
    });
  } catch (error: any) {
    console.error("Error agregando tarjeta:", error);
    res.status(500).json({ error: error.message });
  }
};

export const getTarjetas = async (req: Request, res: Response): Promise<void> => {
  try {
    const usuarioId = (req as any).user?.uid;
    if (!usuarioId) {
      res.status(401).json({ error: "No autorizado" });
      return;
    }

    const snapshot = await db.collection("tarjetas_usuarios")
      .where("usuario_id", "==", usuarioId)
      .where("activa", "==", true)
      .get();

    const tarjetas = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.status(200).json(tarjetas);
  } catch (error: any) {
    console.error("Error obteniendo tarjetas:", error);
    res.status(500).json({ error: error.message });
  }
};

export const eliminarTarjeta = async (req: Request, res: Response): Promise<void> => {
  try {
    const { tarjetaId } = req.params;
    const usuarioId = (req as any).user?.uid;

    const tarjetaDoc = await db.collection("tarjetas_usuarios").doc(tarjetaId).get();

    if (!tarjetaDoc.exists) {
      res.status(404).json({ error: "Tarjeta no encontrada" });
      return;
    }

    const tarjetaData = tarjetaDoc.data();
    if (tarjetaData?.usuario_id !== usuarioId) {
      res.status(403).json({ error: "No tienes permiso para eliminar esta tarjeta" });
      return;
    }

    await db.collection("tarjetas_usuarios").doc(tarjetaId).update({
      activa: false,
      fecha_actualizacion: FieldValue.serverTimestamp(),
    });

    res.status(200).json({ message: "Tarjeta eliminada" });
  } catch (error: any) {
    console.error("Error eliminando tarjeta:", error);
    res.status(500).json({ error: error.message });
  }
};
