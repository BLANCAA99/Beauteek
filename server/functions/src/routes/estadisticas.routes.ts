import { Router } from "express";
import { getEstadisticasSalon } from "../controllers/estadisticas.controller";
import { verifyToken } from "../middleware/auth.middleware";

const router = Router();

router.get('/salon/:comercioId', verifyToken, getEstadisticasSalon);

export default router;
