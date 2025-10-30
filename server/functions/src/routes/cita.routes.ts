import { Router } from 'express';
import {
  createCita,
  getCitas,
  getCitaById,
  updateCita,
  deleteCita,
} from '../controllers/cita.controller';

const router = Router();

router.post('/', createCita);
router.get('/', getCitas);
router.get('/:id', getCitaById);
router.put('/:id', updateCita);
router.delete('/:id', deleteCita);

export default router;
