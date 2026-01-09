import { Router } from 'express';
import { buscarSalonesPorPais } from '../controllers/buscar_salones_pais.controller';

const router = Router();

// Buscar salones por país del usuario
router.get('/pais', buscarSalonesPorPais);

export default router;
