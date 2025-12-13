import { Request, Response } from 'express';
import { db } from '../config/firebase';
import { Ubicacion, UbicacionCreateDTO, UbicacionUpdateDTO } from '../modelos/ubicacion.model';

/**
 * Crear una nueva ubicación
 * POST /api/ubicaciones
 */
export const crearUbicacion = async (req: Request, res: Response): Promise<void> => {
  try {
    const data: UbicacionCreateDTO = req.body;
    const { uid_usuario, tipo_entidad, pais, lat, lng } = data;

    // Validaciones
    if (!uid_usuario || !tipo_entidad || !pais || lat === undefined || lng === undefined) {
      res.status(400).json({ 
        error: 'Campos requeridos: uid_usuario, tipo_entidad, pais, lat, lng' 
      });
      return;
    }

    if (!['cliente', 'salon'].includes(tipo_entidad)) {
      res.status(400).json({ error: 'tipo_entidad debe ser "cliente" o "salon"' });
      return;
    }

    // Si es_principal=true, desmarcar otras ubicaciones principales del mismo usuario
    if (data.es_principal) {
      const ubicacionesExistentes = await db
        .collection('ubicaciones')
        .where('uid_usuario', '==', uid_usuario)
        .where('tipo_entidad', '==', tipo_entidad)
        .where('es_principal', '==', true)
        .where('activo', '==', true)
        .get();

      const batch = db.batch();
      ubicacionesExistentes.docs.forEach((doc) => {
        batch.update(doc.ref, { es_principal: false });
      });
      await batch.commit();
    }

    // Si es la primera ubicación, hacerla principal automáticamente
    let esPrincipal = data.es_principal ?? false;
    if (!esPrincipal) {
      const countQuery = await db
        .collection('ubicaciones')
        .where('uid_usuario', '==', uid_usuario)
        .where('tipo_entidad', '==', tipo_entidad)
        .where('activo', '==', true)
        .get();
      
      if (countQuery.empty) {
        esPrincipal = true;
      }
    }

    const nuevaUbicacion: Ubicacion = {
      uid_usuario,
      tipo_entidad,
      es_principal: esPrincipal,
      pais: pais.trim(),
      ciudad: data.ciudad?.trim(),
      direccion_completa: data.direccion_completa?.trim(),
      lat,
      lng,
      alias: data.alias?.trim(),
      fecha_creacion: new Date() as any,
      fecha_actualizacion: new Date() as any,
      activo: true,
    };

    const docRef = await db.collection('ubicaciones').add(nuevaUbicacion);

    console.log(`✅ Ubicación creada: ${docRef.id} para ${uid_usuario}`);
    res.status(201).json({ id: docRef.id, ...nuevaUbicacion });
  } catch (error: any) {
    console.error('❌ Error creando ubicación:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Obtener todas las ubicaciones de un usuario
 * GET /api/ubicaciones/usuario/:uid
 */
export const obtenerUbicacionesUsuario = async (req: Request, res: Response): Promise<void> => {
  try {
    const { uid } = req.params;
    const { tipo } = req.query; // opcional: filtrar por tipo_entidad

    let query = db
      .collection('ubicaciones')
      .where('uid_usuario', '==', uid)
      .where('activo', '==', true);

    if (tipo && ['cliente', 'salon'].includes(tipo as string)) {
      query = query.where('tipo_entidad', '==', tipo);
    }

    const snapshot = await query.get();

    const ubicaciones = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(ubicaciones);
  } catch (error: any) {
    console.error('❌ Error obteniendo ubicaciones:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Obtener la ubicación principal de un usuario
 * GET /api/ubicaciones/principal/:uid
 */
export const obtenerUbicacionPrincipal = async (req: Request, res: Response): Promise<void> => {
  try {
    const { uid } = req.params;
    const { tipo } = req.query; // opcional: cliente o salon

    let query = db
      .collection('ubicaciones')
      .where('uid_usuario', '==', uid)
      .where('es_principal', '==', true)
      .where('activo', '==', true);

    if (tipo && ['cliente', 'salon'].includes(tipo as string)) {
      query = query.where('tipo_entidad', '==', tipo);
    }

    const snapshot = await query.limit(1).get();

    if (snapshot.empty) {
      res.status(404).json({ 
        error: 'No se encontró ubicación principal',
        message: 'El usuario debe configurar su ubicación primero'
      });
      return;
    }

    const ubicacion = {
      id: snapshot.docs[0].id,
      ...snapshot.docs[0].data(),
    };

    res.json(ubicacion);
  } catch (error: any) {
    console.error('❌ Error obteniendo ubicación principal:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Actualizar una ubicación
 * PUT /api/ubicaciones/:id
 */
export const actualizarUbicacion = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const data: UbicacionUpdateDTO = req.body;

    const docRef = db.collection('ubicaciones').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      res.status(404).json({ error: 'Ubicación no encontrada' });
      return;
    }

    const ubicacionActual = doc.data() as Ubicacion;

    // Si se marca como principal, desmarcar otras
    if (data.es_principal) {
      const otrasUbicaciones = await db
        .collection('ubicaciones')
        .where('uid_usuario', '==', ubicacionActual.uid_usuario)
        .where('tipo_entidad', '==', ubicacionActual.tipo_entidad)
        .where('es_principal', '==', true)
        .where('activo', '==', true)
        .get();

      const batch = db.batch();
      otrasUbicaciones.docs.forEach((d) => {
        if (d.id !== id) {
          batch.update(d.ref, { es_principal: false });
        }
      });
      await batch.commit();
    }

    const updateData: any = {
      ...data,
      fecha_actualizacion: new Date(),
    };

    await docRef.update(updateData);

    console.log(`✅ Ubicación actualizada: ${id}`);
    res.json({ id, ...updateData });
  } catch (error: any) {
    console.error('❌ Error actualizando ubicación:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Marcar ubicación como principal
 * PUT /api/ubicaciones/:id/principal
 */
export const marcarComoPrincipal = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const docRef = db.collection('ubicaciones').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      res.status(404).json({ error: 'Ubicación no encontrada' });
      return;
    }

    const ubicacion = doc.data() as Ubicacion;

    // Desmarcar otras ubicaciones principales
    const otrasUbicaciones = await db
      .collection('ubicaciones')
      .where('uid_usuario', '==', ubicacion.uid_usuario)
      .where('tipo_entidad', '==', ubicacion.tipo_entidad)
      .where('es_principal', '==', true)
      .where('activo', '==', true)
      .get();

    const batch = db.batch();
    otrasUbicaciones.docs.forEach((d) => {
      if (d.id !== id) {
        batch.update(d.ref, { es_principal: false });
      }
    });

    // Marcar esta como principal
    batch.update(docRef, { 
      es_principal: true,
      fecha_actualizacion: new Date()
    });

    await batch.commit();

    console.log(`✅ Ubicación ${id} marcada como principal`);
    res.json({ message: 'Ubicación marcada como principal', id });
  } catch (error: any) {
    console.error('❌ Error marcando como principal:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Eliminar ubicación (soft delete)
 * DELETE /api/ubicaciones/:id
 */
export const eliminarUbicacion = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const docRef = db.collection('ubicaciones').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      res.status(404).json({ error: 'Ubicación no encontrada' });
      return;
    }

    const ubicacion = doc.data() as Ubicacion;

    // No permitir eliminar si es la única ubicación activa
    const countQuery = await db
      .collection('ubicaciones')
      .where('uid_usuario', '==', ubicacion.uid_usuario)
      .where('tipo_entidad', '==', ubicacion.tipo_entidad)
      .where('activo', '==', true)
      .get();

    if (countQuery.size === 1) {
      res.status(400).json({ 
        error: 'No puedes eliminar tu única ubicación',
        message: 'Debes tener al menos una ubicación activa'
      });
      return;
    }

    // Soft delete
    await docRef.update({ 
      activo: false,
      fecha_actualizacion: new Date()
    });

    // Si era principal, marcar otra como principal
    if (ubicacion.es_principal) {
      const otraUbicacion = await db
        .collection('ubicaciones')
        .where('uid_usuario', '==', ubicacion.uid_usuario)
        .where('tipo_entidad', '==', ubicacion.tipo_entidad)
        .where('activo', '==', true)
        .limit(1)
        .get();

      if (!otraUbicacion.empty) {
        await otraUbicacion.docs[0].ref.update({ es_principal: true });
      }
    }

    console.log(`✅ Ubicación eliminada (soft): ${id}`);
    res.json({ message: 'Ubicación eliminada', id });
  } catch (error: any) {
    console.error('❌ Error eliminando ubicación:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Obtener salones por país
 * GET /api/ubicaciones/salones/pais/:pais
 */
export const obtenerSalonesPorPais = async (req: Request, res: Response): Promise<void> => {
  try {
    const { pais } = req.params;

    if (!pais) {
      res.status(400).json({ error: 'País requerido' });
      return;
    }

    console.log(`🌍 Buscando salones en país: ${pais}`);

    // Buscar ubicaciones de salones en ese país
    const ubicacionesSnapshot = await db
      .collection('ubicaciones')
      .where('tipo_entidad', '==', 'salon')
      .where('pais', '==', pais)
      .where('activo', '==', true)
      .get();

    console.log(`📍 Ubicaciones encontradas: ${ubicacionesSnapshot.size}`);

    // Obtener datos de comercios para cada ubicación
    const salonesPromises = ubicacionesSnapshot.docs.map(async (ubicacionDoc) => {
      const ubicacion = ubicacionDoc.data() as Ubicacion;
      const uidNegocio = ubicacion.uid_usuario;

      // Buscar el comercio por uid_negocio
      const comerciosSnapshot = await db
        .collection('comercios')
        .where('uid_negocio', '==', uidNegocio)
        .where('estado', '==', 'activo')
        .limit(1)
        .get();

      if (comerciosSnapshot.empty) {
        return null;
      }

      const comercioDoc = comerciosSnapshot.docs[0];
      const comercio = comercioDoc.data();

      // Obtener servicios
      const serviciosSnapshot = await db
        .collection('servicios')
        .where('comercio_id', '==', comercioDoc.id)
        .where('activo', '==', true)
        .get();

      const servicios = serviciosSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      return {
        id: comercioDoc.id,
        ubicacion_id: ubicacionDoc.id,
        nombre: comercio.nombre || 'Sin nombre',
        telefono: comercio.telefono || '',
        email: comercio.email || '',
        foto_url: comercio.foto_url || '',
        descripcion: comercio.descripcion || '',
        calificacion: comercio.calificacion || 4.5,
        direccion: ubicacion.direccion_completa || comercio.direccion || '',
        ciudad: ubicacion.ciudad || '',
        pais: ubicacion.pais,
        ubicacion: {
          lat: ubicacion.lat,
          lng: ubicacion.lng,
        },
        servicios,
      };
    });

    const salones = (await Promise.all(salonesPromises)).filter((s) => s !== null);

    console.log(`✅ ${salones.length} salones encontrados en ${pais}`);
    res.json(salones);
  } catch (error: any) {
    console.error('❌ Error obteniendo salones por país:', error);
    res.status(500).json({ error: error.message });
  }
};
