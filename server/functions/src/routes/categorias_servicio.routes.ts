import { Router } from 'express';
import {
  createCategoriaServicio,
  getCategoriasServicio,
  getCategoriaServicioById,
  updateCategoriaServicio,
  deleteCategoriaServicio,
  inicializarCatalogo,
  getCategorias,
  getCategoriaById,
} from '../controllers/categorias_servicio.controller';

const router = Router();

router.post('/', createCategoriaServicio);
router.get('/', getCategoriasServicio);
router.get('/:id', getCategoriaServicioById);
router.put('/:id', updateCategoriaServicio);
router.delete('/:id', deleteCategoriaServicio);

// Ruta para inicializar el catálogo (ejecutar solo una vez)
router.post('/inicializar-catalogo', inicializarCatalogo);

// Rutas públicas para obtener categorías
router.get('/', getCategorias);
router.get('/:id', getCategoriaById);

export default router;
