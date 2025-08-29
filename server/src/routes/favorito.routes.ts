import { Router } from 'express';
import {
  createFavorito,
  getFavoritos,
  getFavoritoById,
  updateFavorito,
  deleteFavorito,
} from '../controllers/favorito.controller';

const router = Router();

router.post('/', createFavorito);
router.get('/', getFavoritos);
router.get('/:id', getFavoritoById);
router.put('/:id', updateFavorito);
router.delete('/:id', deleteFavorito);

export default router;
