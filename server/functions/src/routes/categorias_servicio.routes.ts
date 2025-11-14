import { Router } from 'express';
import {
  createCategoriaServicio,
  updateCategoriaServicio,
  deleteCategoriaServicio,
  inicializarCatalogo,
  getCategorias,
  getCategoriaById,
} from '../controllers/categorias_servicio.controller';

const router = Router();

// Ruta para inicializar el catálogo (ejecutar solo una vez)
router.post('/inicializar-catalogo', inicializarCatalogo);

// Rutas públicas para obtener categorías (estas deben ir primero para evitar conflictos)
router.get('/', getCategorias);
router.get('/:id', getCategoriaById);

// CRUD de categorías de servicio
router.post('/', createCategoriaServicio);
router.put('/:id', updateCategoriaServicio);
router.delete('/:id', deleteCategoriaServicio);

export default router;
