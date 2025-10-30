import { Router } from 'express';
import {
  createServicio,
  getServicios,
  getServicioById,
  updateServicio,
  deleteServicio,
} from '../controllers/servicio.controller';

const router = Router();

router.post('/', createServicio);
router.get('/', getServicios);
router.get('/:id', getServicioById);
router.put('/:id', updateServicio);
router.delete('/:id', deleteServicio);

export default router;
