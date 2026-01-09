import { Router } from 'express';
import { getCitasUsuario, verificarDisponibilidad } from '../controllers/citas.controller';

const router = Router();

// Obtener citas de un usuario con toda la información procesada
router.get('/usuario/:userId', getCitasUsuario);

// Verificar disponibilidad de horarios
router.get('/disponibilidad', verificarDisponibilidad);

export default router;
