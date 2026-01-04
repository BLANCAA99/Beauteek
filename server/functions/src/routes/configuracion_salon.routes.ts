import { Router } from 'express';
import { getConfiguracionSalon, updateConfiguracionSalon } from '../controllers/configuracion_salon.controller';
import { verifyToken } from '../middleware/auth.middleware';

const router = Router();

router.get('/:comercioId', verifyToken, getConfiguracionSalon);
router.put('/:comercioId', verifyToken, updateConfiguracionSalon);

export default router;
