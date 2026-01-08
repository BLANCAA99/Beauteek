import { Router } from 'express';
import {
  createResena,
  getResenas,
  getResenasByComercio,
  getResenaById,
  updateResena,
  deleteResena,
} from '../controllers/reseña.controller';
import { validateReviewImage } from '../middleware/image-validator.middleware';

const router = Router();

router.post('/', validateReviewImage, createResena);
router.get('/', getResenas);
router.get('/comercio/:comercioId', getResenasByComercio); // Nueva ruta específica
router.get('/:id', getResenaById);
router.put('/:id', updateResena);
router.delete('/:id', deleteResena);

export default router;
