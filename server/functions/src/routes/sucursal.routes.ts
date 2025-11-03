import { Router } from 'express';
import {
  createSucursal,
  getSucursalesByComercio,
  updateSucursal,
  deleteSucursal,
} from '../controllers/sucursal.controller';

const router = Router();

router.post('/sucursales', createSucursal);
router.get('/sucursales', getSucursalesByComercio); // ?comercio=<id>
router.put('/sucursales/:id', updateSucursal);
router.delete('/sucursales/:id', deleteSucursal);

export default router;
