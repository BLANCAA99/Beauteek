import { Router } from 'express';
import {
  createPromocion,
  getPromociones,
  getPromocionById,
  updatePromocion,
  deletePromocion,
} from '../controllers/promocion.controller';

const router = Router();

router.post('/', createPromocion);
router.get('/', getPromociones);
router.get('/:id', getPromocionById);
router.put('/:id', updatePromocion);
router.delete('/:id', deletePromocion);

export default router;
