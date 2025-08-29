import { Router } from 'express';
import {
  createHorario,
  getHorarios,
  getHorarioById,
  updateHorario,
  deleteHorario,
} from '../controllers/horario.controller';

const router = Router();

router.post('/', createHorario);
router.get('/', getHorarios);
router.get('/:id', getHorarioById);
router.put('/:id', updateHorario);
router.delete('/:id', deleteHorario);

export default router;
