import { Router } from 'express';
import {
  createPago,
  getPagos,
  getPagoById,
} from '../controllers/pago.controller';

const router = Router();

router.post('/', createPago);
router.get('/', getPagos);
router.get('/:id', getPagoById);

export default router;
