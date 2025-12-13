import { Router } from 'express';
import {
  registerSalonStep1,
  registerSalonStep2,
  registerSalonStep3,
  registerSalonStep4,
  getComercios,
  getComercioById,
  updateComercio,
  deleteComercio,
  getComercioscerca,
  getComerciosPorPais,
} from '../controllers/comercio.controller';
import { verifyToken } from '../middleware/auth.middleware';

const router = Router();

// ✅ RUTAS ESPECÍFICAS PRIMERO (sin parámetros dinámicos)
router.get('/cerca', verifyToken, getComercioscerca);
router.get('/pais/:pais', verifyToken, getComerciosPorPais);

// Rutas para registro por pasos (si las usas, sino eliminar)
router.post('/register-salon-step1', verifyToken, registerSalonStep1);
router.post('/register-salon-step2', verifyToken, registerSalonStep2);
router.post('/register-salon-step3', verifyToken, registerSalonStep3);
router.post('/register-salon-step4', verifyToken, registerSalonStep4);

// ✅ RUTAS CRUD
router.post('/', verifyToken, async (req, res): Promise<void> => { // ✅ CAMBIO: Agregar Promise<void>
  try {
    const {
      nombre,
      direccion,
      ubicacion,
      telefono,
      foto_url,
      servicios,
      horarios,
    } = req.body;

    const uid_negocio = (req as any).user?.uid;

    if (!uid_negocio) {
      res.status(401).json({ error: "Usuario no autenticado" });
      return; // ✅ AGREGAR return
    }

    if (!ubicacion || typeof ubicacion.lat !== 'number' || typeof ubicacion.lng !== 'number') {
      res.status(400).json({ error: "ubicacion debe tener {lat, lng}" });
      return; // ✅ AGREGAR return
    }

    const admin = require('firebase-admin');
    const db = admin.firestore();

    const comercioData = {
      uid_negocio,
      nombre: nombre || "",
      direccion: direccion || "",
      ubicacion: new admin.firestore.GeoPoint(ubicacion.lat, ubicacion.lng),
      telefono: telefono || "",
      foto_url: foto_url || "",
      servicios: servicios || [],
      horarios: horarios || [],
      estado: "activo",
      calificacion: 0,
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection("comercios").add(comercioData);

    res.status(201).json({
      id: docRef.id,
      mensaje: "Comercio creado exitosamente",
    });
  } catch (error: any) {
    console.error("Error creando comercio:", error);
    res.status(500).json({ error: error.message });
  }
});

router.get('/', verifyToken, getComercios);
router.get('/:id', verifyToken, getComercioById);
router.put('/:id', verifyToken, updateComercio);
router.delete('/:id', verifyToken, deleteComercio);

export default router;
