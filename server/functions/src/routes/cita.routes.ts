import { Router } from 'express';
import {
  createCita,
  getCitas,
  getCitaById,
  getCitasByUsuario, // ✅ AGREGAR IMPORT
  updateCita,
  deleteCita,
} from '../controllers/cita.controller';

const router = Router();

router.post('/', createCita);
router.get('/', getCitas);
router.get('/usuario/:userId', getCitasByUsuario); // ✅ AGREGAR RUTA (antes de /:id)
router.get('/:id', getCitaById);
router.put('/:id', updateCita);
router.delete('/:id', deleteCita);

export default router;
