import { Request, Response } from 'express';
import { db } from '../config/firebase';
import { GaleriaFotoSchema } from '../modelos/galeria_foto.model';

const galeriaFotosCollection = db.collection('galeria_fotos');

/**
 * Crear una nueva foto en la galería
 * POST /galeria-fotos
 * Body: { comercio_id, foto_url, descripcion?, servicio_id?, servicio_nombre? }
 */
export const crearFoto = async (req: Request, res: Response) => {
  try {
    const validacion = GaleriaFotoSchema
      .omit({ id: true, fecha_creacion: true })
      .safeParse(req.body);

    if (!validacion.success) {
      return res.status(400).json({
        error: 'Datos inválidos',
        detalles: validacion.error.issues,
      });
    }

    const {
      comercio_id,
      foto_url,
      descripcion,
      servicio_id,
      servicio_nombre,
    } = validacion.data;

    const nuevaFoto = {
      comercio_id,
      foto_url,
      descripcion: descripcion || '',
      // 👇 se guardan también estos campos
      servicio_id: servicio_id || null,
      servicio_nombre: servicio_nombre || '',
      fecha_creacion: new Date(),
    };

    const docRef = await galeriaFotosCollection.add(nuevaFoto);

    return res.status(201).json({
      id: docRef.id,
      ...nuevaFoto,
    });
  } catch (error: any) {
    console.error('Error al crear foto:', error);
    return res.status(500).json({ error: error.message });
  }
};

/**
 * Obtener fotos de un comercio
 * GET /galeria-fotos/comercio/:comercioId
 */
export const obtenerFotosPorComercio = async (req: Request, res: Response) => {
  try {
    const { comercioId } = req.params;

    const snapshot = await galeriaFotosCollection
      .where('comercio_id', '==', comercioId)
      .get();

    const fotos = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return res.status(200).json(fotos);
  } catch (error: any) {
    console.error('Error al obtener fotos:', error);
    return res.status(500).json({ error: error.message });
  }
};

/**
 * Eliminar una foto
 * DELETE /galeria-fotos/:id
 */
export const eliminarFoto = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    await galeriaFotosCollection.doc(id).delete();

    return res.status(200).json({
      message: 'Foto eliminada correctamente',
    });
  } catch (error: any) {
    console.error('Error al eliminar foto:', error);
    return res.status(500).json({ error: error.message });
  }
};

/**
 * Actualizar descripción de una foto
 * PATCH /galeria-fotos/:id
 * Body: { descripcion }
 */
export const actualizarDescripcion = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { descripcion } = req.body;

    if (typeof descripcion !== 'string') {
      return res.status(400).json({
        error: 'La descripción debe ser un texto',
      });
    }

    await galeriaFotosCollection.doc(id).update({
      descripcion,
    });

    return res.status(200).json({
      message: 'Descripción actualizada correctamente',
    });
  } catch (error: any) {
    console.error('Error al actualizar descripción:', error);
    return res.status(500).json({ error: error.message });
  }
};