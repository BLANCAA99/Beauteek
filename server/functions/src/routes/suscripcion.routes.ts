import { Router } from "express";
import {
  crearSuscripcion,
  obtenerSuscripcionPorComercio,
  obtenerSuscripcionesPorDueno,
  actualizarTarjetaSuscripcion,
  actualizarSuscripcion,
  cancelarSuscripcion,
  obtenerHistorialTarjetas,
  obtenerSuscripcionesProximasRenovar,
} from "../controllers/suscripcion.controller";
import { verifyToken } from "../middleware/auth.middleware";

const router = Router();

// Todas las rutas requieren autenticación
router.use(verifyToken);

// Crear suscripción
router.post("/", crearSuscripcion);

// Obtener suscripción por comercio
router.get("/comercio/:comercioId", obtenerSuscripcionPorComercio);

// Obtener suscripciones por dueño (uid_negocio)
router.get("/dueno/:uid", obtenerSuscripcionesPorDueno);

// Actualizar tarjeta de suscripción (permite cambio de dueño)
router.put("/:id/tarjeta", actualizarTarjetaSuscripcion);

// Actualizar plan o estado
router.put("/:id", actualizarSuscripcion);

// Cancelar suscripción
router.delete("/:id", cancelarSuscripcion);

// Obtener historial de cambios de tarjeta
router.get("/:suscripcionId/historial-tarjetas", obtenerHistorialTarjetas);

// Obtener suscripciones próximas a renovar (para sistema de cobros automáticos)
router.get("/renovacion/proximas", obtenerSuscripcionesProximasRenovar);

export default router;
