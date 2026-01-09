import { Router } from "express";
import { getActividadReciente } from "../controllers/actividad.controller";
import { verifyToken } from "../middleware/auth.middleware";

const router = Router();

router.get('/:uid', verifyToken, getActividadReciente);

export default router;
