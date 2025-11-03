import { Router } from 'express';
import {
  registerSalonStep1,
  registerSalonStep2,
  registerSalonStep3,
  getComercios,
  getComercioById,
  updateComercio,
  deleteComercio,
} from '../controllers/comercio.controller';
import { verifyToken } from '../middleware/auth.middleware';

const router = Router();

// Rutas para registro por pasos (requieren autenticación del propietario)
router.post('/register-salon-step1', verifyToken, registerSalonStep1);
router.post('/register-salon-step2', verifyToken, registerSalonStep2);
router.post('/register-salon-step3', verifyToken, registerSalonStep3);

// Rutas CRUD estándar
router.get('/', getComercios);
router.get('/:id', getComercioById);
router.put('/:id', verifyToken, updateComercio);
router.delete('/:id', verifyToken, deleteComercio);

export default router;
