import { Router } from 'express';
import { agregarTarjeta, getTarjetas, eliminarTarjeta } from '../controllers/tarjeta.controller';
import { verifyToken } from '../middleware/auth.middleware';

const router = Router();

router.post('/', verifyToken, agregarTarjeta);
router.get('/', verifyToken, getTarjetas);
router.delete('/:tarjetaId', verifyToken, eliminarTarjeta);

export default router;
