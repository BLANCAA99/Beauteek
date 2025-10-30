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
router.put('/:id', updateUser);
router.delete('/:id', deleteUser);

export default router;