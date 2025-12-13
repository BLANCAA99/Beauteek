import { Router } from 'express';
import {
  createPromocion,
  getPromociones,
  getPromocionById,
  updatePromocion,
  deletePromocion,
} from '../controllers/promocion.controller';

const router = Router();

router.post('/', createPromocion);
router.get('/', getPromociones);
router.get('/comercio/:comercioId', async (req, res) => {
  try {
    const snapshot = await require('../config/firebase').db
      .collection('promociones')
      .where('comercio_id', '==', req.params.comercioId)
      .get();
    const promociones = snapshot.docs.map((doc: any) => ({ id: doc.id, ...doc.data() }));
    res.json(promociones);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});
router.get('/:id', getPromocionById);
router.put('/:id', updatePromocion);
router.delete('/:id', deletePromocion);

export default router;
