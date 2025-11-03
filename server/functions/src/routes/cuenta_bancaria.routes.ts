import { Router } from 'express';
import {
  createCuentaBancaria,
  getCuentasByComercio,
  updateCuentaBancaria,
  deleteCuentaBancaria,
} from '../controllers/cuenta_bancaria.controller';

const router = Router();

router.post('/cuentas_bancarias', createCuentaBancaria);
router.get('/cuentas_bancarias', getCuentasByComercio); // ?comercio=<id>
router.put('/cuentas_bancarias/:id', updateCuentaBancaria);
router.delete('/cuentas_bancarias/:id', deleteCuentaBancaria);

export default router;
