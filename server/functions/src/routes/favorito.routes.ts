import { Router } from 'express';
import {
  createFavorito,
  getFavoritos,
  getFavoritosConDatos,
  getFavoritoById,
  updateFavorito,
  deleteFavorito,
} from '../controllers/favorito.controller';
import { verifyToken } from '../middleware/auth.middleware';

const router = Router();

router.post('/', createFavorito);
router.get('/', getFavoritos);
router.get('/usuario/:userId', verifyToken, getFavoritosConDatos);
router.get('/:id', getFavoritoById);
router.put('/:id', updateFavorito);
router.delete('/:id', deleteFavorito);

export default router;
