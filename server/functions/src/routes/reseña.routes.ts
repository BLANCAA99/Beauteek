import { Router } from 'express';
import {
  createResena,
  getResenas,
  getResenaById,
  updateResena,
  deleteResena,
} from '../controllers/reseña.controller';

const router = Router();

router.post('/', createResena);
router.get('/', getResenas);
router.get('/:id', getResenaById);
router.put('/:id', updateResena);
router.delete('/:id', deleteResena);

export default router;
