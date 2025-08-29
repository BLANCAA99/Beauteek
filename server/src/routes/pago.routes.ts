import { Router } from 'express';
import {
  createPago,
  getPagos,
  getPagoById,
  updatePago,
  deletePago,
} from '../controllers/pago.controller';

const router = Router();

router.post('/', createPago);
router.get('/', getPagos);
router.get('/:id', getPagoById);
router.put('/:id', updatePago);
router.delete('/:id', deletePago);

export default router;
