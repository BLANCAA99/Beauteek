import { Request, Response } from "express";
import { db } from "../config/firebase";
import * as admin from "firebase-admin";
import { GeoPoint } from "firebase-admin/firestore";
import { z } from "zod";

// ✅ Tipos actualizados
interface Comercio {
  id?: string;
  uid_cliente_propietario: string;
  uid_negocio: string;
  nombre: string;
  telefono: string;
  email: string;
  rtn?: string;
  direccion?: string;
  ubicacion?: any;
  estado: string;
  cuenta_bancaria_id?: string;
  foto_url?: string;
  descripcion?: string;
  calificacion?: number;
}

/* =========================
   PASO 1: Registro básico del salón
   ========================= */

const registerStep1Schema = z.object({
  email: z.string().email("Email inválido"),
  password: z.string().min(6, "La contraseña debe tener al menos 6 caracteres"),
  nombre: z.string().min(1, "El nombre del salón es requerido"),
  telefono: z.string().min(8, "El teléfono debe tener al menos 8 dígitos"),
  rtn: z.string().length(14, "El RTN debe tener exactamente 14 dígitos").regex(/^\d+$/, "El RTN solo debe contener números"),
});

export const registerSalonStep1 = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = registerStep1Schema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos inválidos", details: parsed.error.issues });
      return;
    }

    const { email, password, nombre, telefono, rtn } = parsed.data;
    const uidPropietario = (req as any).user?.uid;
    
    if (!uidPropietario) {
      res.status(401).json({ error: "No autorizado" });
      return;
    }

    const salonUserRecord = await admin.auth().createUser({
      email,
      password,
      displayName: nombre,
    });

    const uidNegocio = salonUserRecord.uid;
    await admin.auth().setCustomUserClaims(uidNegocio, { role: "salon" });

    const now = new Date();
    
    await db.collection("usuarios").doc(uidNegocio).set({
      uid: uidNegocio,
      nombre_completo: nombre,
      email,
      telefono,
      rol: "salon",
      estado: "incompleto",
      direccion: "pendiente",
      genero: "no_aplica",
      fecha_nacimiento: "no_aplica",
      foto_url: "",
      verificacion_bancaria_status: "pending",
      fecha_creacion: now,
    });

    const comercioRef = db.collection("comercios").doc();
    const comercioId = comercioRef.id;

    await comercioRef.set({
      id_documento: comercioId,
      uid_cliente_propietario: uidPropietario,
      uid_negocio: uidNegocio,
      nombre,
      telefono,
      email,
      rtn,
      estado: "paso1_completado",
      fecha_creacion: now,
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
   PASO 2: Agregar ubicación AL COMERCIO
   ========================= */

const registerStep2Schema = z.object({
  comercioId: z.string().min(1),
  direccion: z.string().min(5, "La dirección debe tener al menos 5 caracteres"),
  ubicacion: z.object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
  }),
});

export const registerSalonStep2 = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = registerStep2Schema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos inválidos", details: parsed.error.issues });
      return;
    }

    const { comercioId, direccion, ubicacion } = parsed.data;
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

    console.log('📍 Guardando ubicación:', ubicacion);
    
    // ✅ CAMBIO: Crear GeoPoint con el import correcto
    const geoPoint = new GeoPoint(ubicacion.latitude, ubicacion.longitude);
    console.log('📍 GeoPoint creado:', geoPoint);

    await db.collection("comercios").doc(comercioId).update({
      direccion,
      ubicacion: geoPoint,
      estado: "paso2_completado",
      fecha_actualizacion: new Date(),
    });

    console.log('✅ Ubicación guardada correctamente');

    res.status(200).json({
      message: "Paso 2 completado: Ubicación agregada al comercio",
      comercioId,
    });
  } catch (error: any) {
    console.error("Error en registerSalonStep2:", error);
    res.status(500).json({ error: error.message });
  }
};

/* =========================
   PASO 3: Agregar cuenta bancaria
   ========================= */

const registerStep3Schema = z.object({
  comercioId: z.string().min(1),
  banco: z.string().min(1, "El nombre del banco es requerido"),
  tipo_cuenta: z.enum(['ahorro', 'corriente'] as const),
  numero_cuenta: z.string().min(5, "El número de cuenta es requerido"),
  nombre_titular: z.string().min(1, "El nombre del titular es requerido"),
  identificacion_titular: z.string().min(5, "La identificación del titular es requerida"),
});

export const registerSalonStep3 = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = registerStep3Schema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos inválidos", details: parsed.error.issues });
      return;
    }

    const { comercioId, banco, tipo_cuenta, numero_cuenta, nombre_titular, identificacion_titular } = parsed.data;
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
    const cuentaBancariaRef = db.collection("cuentas_bancarias").doc();
    
    await cuentaBancariaRef.set({
      id_documento: cuentaBancariaRef.id,
      usuario_id: uidNegocio,
      comercio_id: comercioId,
      banco,
      tipo_cuenta,
      numero_cuenta,
      nombre_titular,
      identificacion_titular,
      estado: "pendiente_verificacion",
      fecha_creacion: new Date(),
    });

    await db.collection("comercios").doc(comercioId).update({
      estado: "paso3_completado",
      cuenta_bancaria_id: cuentaBancariaRef.id,
      fecha_actualizacion: new Date(),
    });

    res.status(200).json({
      message: "Paso 3 completado: Cuenta bancaria registrada",
      comercioId,
      cuentaBancariaId: cuentaBancariaRef.id,
    });
  } catch (error: any) {
    console.error("Error en registerSalonStep3:", error);
    res.status(500).json({ error: error.message });
  }
};

/* =========================
   PASO 4: Agregar servicios y horarios
   ========================= */

const registerStep4Schema = z.object({
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

export const registerSalonStep4 = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = registerStep4Schema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Datos inválidos", details: parsed.error.issues });
      return;
    }

    const { comercioId, horarios, servicios } = parsed.data;
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
    const batch = db.batch();
    const now = new Date();

    // 3.1 Crear horarios
    horarios.forEach((horario) => {
      const horarioRef = db.collection("horarios").doc();
      batch.set(horarioRef, {
        ...horario,
        usuario_id: uidNegocio,
        comercio_id: comercioId,
        fecha_creacion: now,
      });
    });

    // 3.2 Crear servicios
    servicios.forEach((servicio) => {
      const servicioRef = db.collection("servicios").doc();
      batch.set(servicioRef, {
        ...servicio,
        usuario_id: uidNegocio,
        comercio_id: comercioId,
        fecha_creacion: now,
      });
    });

    // 3.3 Actualizar estado del comercio a 'activo'
    const comercioRef = db.collection("comercios").doc(comercioId);
    batch.update(comercioRef, {
      estado: "activo",
      fecha_activacion: now,
      fecha_actualizacion: now,
    });

    // 3.4 Actualizar estado del usuario
    const usuarioRef = db.collection("usuarios").doc(uidNegocio);
    batch.update(usuarioRef, {
      estado: "activo",
      fecha_actualizacion: now,
    });

    await batch.commit();

    res.status(200).json({
      message: "¡Registro completado! Tu salón está activo.",
      comercioId,
      uidNegocio,
    });
  } catch (error: any) {
    console.error("Error en registerSalonStep4:", error);
    res.status(500).json({ error: error.message });
  }
};

/* =========================
   CRUD estándar
   ========================= */

export const getComercios = async (req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection("comercios").get();
    const comercios: any[] = [];

    snapshot.forEach((doc) => {
      comercios.push({
        id: doc.id,
        ...doc.data(),
      });
    });

    res.json(comercios);
  } catch (error: any) {
    console.error("Error obteniendo comercios:", error);
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
    
    res.json({ id: doc.id, ...doc.data() });
  } catch (error: any) {
    console.error("Error obteniendo comercio:", error);
    res.status(500).json({ error: error.message });
  }
};

export const updateComercio = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("comercios").doc(req.params.id).update({
      ...req.body,
      fecha_actualizacion: new Date(),
    });
    
    res.json({ message: "Comercio actualizado" });
  } catch (error: any) {
    console.error("Error actualizando comercio:", error);
    res.status(500).json({ error: error.message });
  }
};

export const deleteComercio = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("comercios").doc(req.params.id).delete();
    res.json({ message: "Comercio eliminado" });
  } catch (error: any) {
    console.error("Error eliminando comercio:", error);
    res.status(500).json({ error: error.message });
  }
};

/* =========================
   Búsqueda por cercanía
   ========================= */

export const getComercioscerca = async (req: Request, res: Response): Promise<void> => {
  try {
    const { lat, lng, radio = '50' } = req.query;
    
    if (!lat || !lng) {
      res.status(400).json({ error: 'Latitud y longitud requeridas' });
      return;
    }
    
    const userLat = parseFloat(lat as string);
    const userLng = parseFloat(lng as string);
    const radioKm = parseFloat(radio as string) || 50;
    
    console.log(`🔍 Buscando comercios cerca de (${userLat}, ${userLng}) - Radio: ${radioKm}km`);

    const comerciosSnapshot = await db
      .collection('comercios')
      .where('estado', '==', 'activo')
      .get();

    const comerciosCercanos: any[] = [];

    for (const comercioDoc of comerciosSnapshot.docs) {
      const comercio = comercioDoc.data() as Comercio;
      const comercioId = comercioDoc.id;

      if (!comercio.ubicacion) {
        console.log(`⚠️ Comercio ${comercioId} sin ubicación`);
        continue;
      }

      let comercioLat: number | undefined;
      let comercioLng: number | undefined;

      if (comercio.ubicacion._latitude !== undefined && comercio.ubicacion._longitude !== undefined) {
        comercioLat = comercio.ubicacion._latitude;
        comercioLng = comercio.ubicacion._longitude;
      } else if ((comercio.ubicacion as any).latitude !== undefined && (comercio.ubicacion as any).longitude !== undefined) {
        comercioLat = (comercio.ubicacion as any).latitude;
        comercioLng = (comercio.ubicacion as any).longitude;
      }

      if (comercioLat === undefined || comercioLng === undefined) {
        console.log(`⚠️ Comercio ${comercioId} con coordenadas inválidas`);
        continue;
      }

      const distancia = calcularDistancia(userLat, userLng, comercioLat, comercioLng);

      if (distancia <= radioKm) {
        const serviciosSnapshot = await db
          .collection('servicios')
          .where('comercio_id', '==', comercioId)
          .where('activo', '==', true)
          .get();

        const servicios = serviciosSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        comerciosCercanos.push({
          id: comercioId,
          nombre: comercio.nombre || 'Sin nombre',
          telefono: comercio.telefono || '',
          email: comercio.email || '',
          foto_url: comercio.foto_url || '',
          descripcion: comercio.descripcion || '',
          calificacion: comercio.calificacion || 4.5,
          distancia: parseFloat(distancia.toFixed(2)),
          direccion: comercio.direccion || '',
          ubicacion: {
            lat: comercioLat,
            lng: comercioLng,
          },
          servicios: servicios,
        });
      }
    }

    comerciosCercanos.sort((a, b) => a.distancia - b.distancia);
    console.log(`✅ ${comerciosCercanos.length} comercios encontrados`);

    res.json(comerciosCercanos);
  } catch (error: any) {
    console.error('❌ Error en getComercioscerca:', error);
    res.status(500).json({ error: error.message });
  }
};

function calcularDistancia(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}
