import { Router } from 'express';
import {
  obtenerFotosPorComercio,
  crearFoto,
  eliminarFoto,
  actualizarDescripcion,
} from '../controllers/galeria_foto.controller';

const router = Router();

// GET /galeria-fotos/comercio/:comercioId - Obtener fotos de un comercio
router.get('/comercio/:comercioId', obtenerFotosPorComercio);

// POST /galeria-fotos - Crear nueva foto
router.post('/', crearFoto);

// PATCH /galeria-fotos/:id - Actualizar descripción
router.patch('/:id', actualizarDescripcion);

// DELETE /galeria-fotos/:id - Eliminar foto
router.delete('/:id', eliminarFoto);

export default router;
