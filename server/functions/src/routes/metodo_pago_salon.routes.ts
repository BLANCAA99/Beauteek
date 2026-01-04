import { Router } from 'express';
import { getMetodosPagoSalon, updateMetodosPagoSalon } from '../controllers/metodo_pago_salon.controller';
import { verifyToken } from '../middleware/auth.middleware';

const router = Router();

router.get('/:comercioId', verifyToken, getMetodosPagoSalon);
router.put('/:comercioId', verifyToken, updateMetodosPagoSalon);

export default router;
