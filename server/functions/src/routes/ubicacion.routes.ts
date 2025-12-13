import { Router } from 'express';
import { verifyToken } from '../middleware/auth.middleware';
import {
  crearUbicacion,
  obtenerUbicacionesUsuario,
  obtenerUbicacionPrincipal,
  actualizarUbicacion,
  marcarComoPrincipal,
  eliminarUbicacion,
  obtenerSalonesPorPais,
} from '../controllers/ubicacion.controller';

const router = Router();

// Crear nueva ubicación
router.post('/', verifyToken, crearUbicacion);

// Obtener todas las ubicaciones de un usuario
router.get('/usuario/:uid', verifyToken, obtenerUbicacionesUsuario);

// Obtener ubicación principal
router.get('/principal/:uid', verifyToken, obtenerUbicacionPrincipal);

// Obtener salones por país
router.get('/salones/pais/:pais', verifyToken, obtenerSalonesPorPais);

// Actualizar ubicación
router.put('/:id', verifyToken, actualizarUbicacion);

// Marcar como principal
router.put('/:id/principal', verifyToken, marcarComoPrincipal);

// Eliminar ubicación (soft delete)
router.delete('/:id', verifyToken, eliminarUbicacion);

export default router;
