import { Request, Response } from "express";
import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";
import { Suscripcion, SuscripcionCreateDTO, SuscripcionUpdateDTO } from "../modelos/suscripcion.model";

// Crear suscripción para un salón
export const crearSuscripcion = async (req: Request, res: Response): Promise<void> => {
  try {
    const { uid_negocio, comercio_id, tarjeta_id, plan, precio_mensual }: SuscripcionCreateDTO = req.body;

    if (!uid_negocio || !comercio_id || !tarjeta_id || !plan || !precio_mensual) {
      res.status(400).json({ error: 'Faltan datos requeridos' });
      return;
    }

    // Verificar que la tarjeta pertenezca al usuario
    const tarjetaDoc = await db.collection('tarjetas').doc(tarjeta_id).get();
    if (!tarjetaDoc.exists) {
      res.status(404).json({ error: 'Tarjeta no encontrada' });
      return;
    }

    const tarjetaData = tarjetaDoc.data();
    if (tarjetaData?.usuario_id !== uid_negocio) {
      res.status(403).json({ error: 'La tarjeta no pertenece a este usuario' });
      return;
    }

    // Verificar si ya existe una suscripción activa para este comercio
    const suscripcionExistente = await db.collection('suscripciones')
      .where('comercio_id', '==', comercio_id)
      .where('estado', '==', 'activa')
      .get();

    if (!suscripcionExistente.empty) {
      res.status(400).json({ error: 'Ya existe una suscripción activa para este salón' });
      return;
    }

    // Calcular fecha del próximo cobro (30 días desde hoy)
    const fechaInicio = new Date();
    const fechaProximoCobro = new Date();
    fechaProximoCobro.setDate(fechaProximoCobro.getDate() + 30);

    const suscripcionData: any = {
      uid_negocio,
      comercio_id,
      tarjeta_id,
      plan,
      estado: 'activa',
      precio_mensual,
      fecha_inicio: fechaInicio.toISOString(),
      fecha_proximo_cobro: fechaProximoCobro.toISOString(),
      fecha_creacion: FieldValue.serverTimestamp(),
      fecha_actualizacion: FieldValue.serverTimestamp(),
    };

    const suscripcionRef = await db.collection('suscripciones').add(suscripcionData);

    console.log(`✅ Suscripción creada: ${suscripcionRef.id}`);

    res.status(201).json({
      mensaje: 'Suscripción creada exitosamente',
      id: suscripcionRef.id,
      ...suscripcionData,
    });
  } catch (error: any) {
    console.error('❌ Error creando suscripción:', error);
    res.status(500).json({ error: error.message });
  }
};

// Obtener suscripción por comercio_id
export const obtenerSuscripcionPorComercio = async (req: Request, res: Response): Promise<void> => {
  try {
    const { comercioId } = req.params;

    const snapshot = await db.collection('suscripciones')
      .where('comercio_id', '==', comercioId)
      .orderBy('fecha_creacion', 'desc')
      .limit(1)
      .get();

    if (snapshot.empty) {
      res.status(404).json({ error: 'No se encontró suscripción para este salón' });
      return;
    }

    const doc = snapshot.docs[0];
    res.json({ id: doc.id, ...doc.data() });
  } catch (error: any) {
    console.error('❌ Error obteniendo suscripción:', error);
    res.status(500).json({ error: error.message });
  }
};

// Obtener suscripciones por uid_negocio (dueño)
export const obtenerSuscripcionesPorDueno = async (req: Request, res: Response): Promise<void> => {
  try {
    const { uid } = req.params;

    const snapshot = await db.collection('suscripciones')
      .where('uid_negocio', '==', uid)
      .orderBy('fecha_creacion', 'desc')
      .get();

    const suscripciones = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(suscripciones);
  } catch (error: any) {
    console.error('❌ Error obteniendo suscripciones:', error);
    res.status(500).json({ error: error.message });
  }
};

// Actualizar tarjeta de suscripción (permite cambio de dueño)
export const actualizarTarjetaSuscripcion = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { tarjeta_id, uid_negocio_nuevo, motivo } = req.body;

    if (!tarjeta_id) {
      res.status(400).json({ error: 'Se requiere tarjeta_id' });
      return;
    }

    const suscripcionDoc = await db.collection('suscripciones').doc(id).get();
    if (!suscripcionDoc.exists) {
      res.status(404).json({ error: 'Suscripción no encontrada' });
      return;
    }

    const suscripcionData = suscripcionDoc.data() as Suscripcion;

    // Verificar que la nueva tarjeta exista
    const tarjetaDoc = await db.collection('tarjetas').doc(tarjeta_id).get();
    if (!tarjetaDoc.exists) {
      res.status(404).json({ error: 'Tarjeta no encontrada' });
      return;
    }

    const tarjetaData = tarjetaDoc.data();

    // Si se proporciona uid_negocio_nuevo, validar que la tarjeta le pertenezca
    if (uid_negocio_nuevo) {
      if (tarjetaData?.usuario_id !== uid_negocio_nuevo) {
        res.status(403).json({ error: 'La tarjeta no pertenece al nuevo dueño' });
        return;
      }
    } else {
      // Si no se proporciona nuevo dueño, validar que la tarjeta pertenezca al dueño actual
      if (tarjetaData?.usuario_id !== suscripcionData.uid_negocio) {
        res.status(403).json({ error: 'La tarjeta no pertenece al dueño actual' });
        return;
      }
    }

    // Guardar historial del cambio
    const historialData: any = {
      suscripcion_id: id,
      uid_negocio_anterior: suscripcionData.uid_negocio,
      uid_negocio_nuevo: uid_negocio_nuevo || suscripcionData.uid_negocio,
      tarjeta_id_anterior: suscripcionData.tarjeta_id,
      tarjeta_id_nueva: tarjeta_id,
      motivo: motivo || 'actualizacion_tarjeta',
      fecha_cambio: FieldValue.serverTimestamp(),
    };

    await db.collection('historial_tarjetas_suscripcion').add(historialData);

    // Actualizar suscripción
    const updateData: any = {
      tarjeta_id,
      fecha_actualizacion: FieldValue.serverTimestamp(),
    };

    if (uid_negocio_nuevo) {
      updateData.uid_negocio = uid_negocio_nuevo;
    }

    await db.collection('suscripciones').doc(id).update(updateData);

    console.log(`✅ Tarjeta de suscripción actualizada: ${id}`);

    res.json({
      mensaje: 'Tarjeta actualizada exitosamente',
      historial_id: historialData.id,
    });
  } catch (error: any) {
    console.error('❌ Error actualizando tarjeta:', error);
    res.status(500).json({ error: error.message });
  }
};

// Actualizar plan o estado de suscripción
export const actualizarSuscripcion = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { plan, estado, precio_mensual }: SuscripcionUpdateDTO = req.body;

    const suscripcionDoc = await db.collection('suscripciones').doc(id).get();
    if (!suscripcionDoc.exists) {
      res.status(404).json({ error: 'Suscripción no encontrada' });
      return;
    }

    const updateData: any = {
      fecha_actualizacion: FieldValue.serverTimestamp(),
    };

    if (plan) updateData.plan = plan;
    if (estado) updateData.estado = estado;
    if (precio_mensual) updateData.precio_mensual = precio_mensual;

    // Si se cancela, guardar fecha de cancelación
    if (estado === 'cancelada') {
      updateData.fecha_cancelacion = new Date().toISOString();
    }

    await db.collection('suscripciones').doc(id).update(updateData);

    console.log(`✅ Suscripción actualizada: ${id}`);

    res.json({ mensaje: 'Suscripción actualizada exitosamente' });
  } catch (error: any) {
    console.error('❌ Error actualizando suscripción:', error);
    res.status(500).json({ error: error.message });
  }
};

// Cancelar suscripción
export const cancelarSuscripcion = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const suscripcionDoc = await db.collection('suscripciones').doc(id).get();
    if (!suscripcionDoc.exists) {
      res.status(404).json({ error: 'Suscripción no encontrada' });
      return;
    }

    await db.collection('suscripciones').doc(id).update({
      estado: 'cancelada',
      fecha_cancelacion: new Date().toISOString(),
      fecha_actualizacion: FieldValue.serverTimestamp(),
    });

    console.log(`✅ Suscripción cancelada: ${id}`);

    res.json({ mensaje: 'Suscripción cancelada exitosamente' });
  } catch (error: any) {
    console.error('❌ Error cancelando suscripción:', error);
    res.status(500).json({ error: error.message });
  }
};

// Obtener historial de cambios de tarjeta
export const obtenerHistorialTarjetas = async (req: Request, res: Response): Promise<void> => {
  try {
    const { suscripcionId } = req.params;

    const snapshot = await db.collection('historial_tarjetas_suscripcion')
      .where('suscripcion_id', '==', suscripcionId)
      .orderBy('fecha_cambio', 'desc')
      .get();

    const historial = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(historial);
  } catch (error: any) {
    console.error('❌ Error obteniendo historial:', error);
    res.status(500).json({ error: error.message });
  }
};

// Obtener suscripciones que necesitan renovación (próximo cobro en los próximos 3 días)
export const obtenerSuscripcionesProximasRenovar = async (req: Request, res: Response): Promise<void> => {
  try {
    const fechaLimite = new Date();
    fechaLimite.setDate(fechaLimite.getDate() + 3);

    const snapshot = await db.collection('suscripciones')
      .where('estado', '==', 'activa')
      .where('fecha_proximo_cobro', '<=', fechaLimite.toISOString())
      .get();

    const suscripciones = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(suscripciones);
  } catch (error: any) {
    console.error('❌ Error obteniendo suscripciones próximas a renovar:', error);
    res.status(500).json({ error: error.message });
  }
};
