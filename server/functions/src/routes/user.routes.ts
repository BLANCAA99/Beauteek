import { Router } from 'express';
import {
  createUser,
  getUsers,
  getUserById,
  getUserByUid, // <-- IMPORTA LA NUEVA FUNCIÓN
  updateUser,
  deleteUser,
} from '../controllers/user.controller';

const router = Router();

router.post('/', createUser);
router.get('/', getUsers);
router.get('/uid/:uid', getUserByUid); // <-- AÑADE LA NUEVA RUTA
router.get('/:id', getUserById);
router.put('/:uid', updateUser); // <-- CAMBIO: de ':id' a ':uid'
router.delete('/:uid', deleteUser); // <-- CAMBIO: de ':id' a ':uid'

export default router;