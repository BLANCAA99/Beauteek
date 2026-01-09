import { Router } from "express";
import { compararServicios } from "../controllers/comparar_servicios.controller";

const router = Router();

// Temporalmente sin auth para debuggear
router.get('/', (req, res, next) => {
  console.log('[RUTA CompararServicios] Ruta ejecutada, llamando controlador...');
  compararServicios(req, res);
});

export default router;
