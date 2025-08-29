import { Router } from 'express';
import {
  createCategoriaServicio,
  getCategoriasServicio,
  getCategoriaServicioById,
  updateCategoriaServicio,
  deleteCategoriaServicio,
} from '../controllers/categorias_servicio.controller';

const router = Router();

router.post('/', createCategoriaServicio);
router.get('/', getCategoriasServicio);
router.get('/:id', getCategoriaServicioById);
router.put('/:id', updateCategoriaServicio);
router.delete('/:id', deleteCategoriaServicio);

export default router;
