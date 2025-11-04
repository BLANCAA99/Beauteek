import { Request, Response } from "express";
import { db } from "../config/firebase";
import { CategoriaServicio } from "../modelos/categoria_servicio.model";
import { z } from "zod";
import { FieldValue } from "firebase-admin/firestore";

// Datos del catálogo de categorías
const CATEGORIAS_CATALOGO = [
  {
    id: 'corte',
    nombre: 'Cortes',
    icon: '✂️',
    servicios_sugeridos: [
      'Corte de Dama',
      'Corte de Caballero',
      'Corte de Niño',
      'Peinado',
    ],
  },
  {
    id: 'coloracion',
    nombre: 'Coloración',
    icon: '🎨',
    servicios_sugeridos: [
      'Tinte Completo',
      'Mechas',
      'Balayage',
      'Ombré',
    ],
  },
  {
    id: 'tratamientos',
    nombre: 'Tratamientos',
    icon: '💆',
    servicios_sugeridos: [
      'Tratamiento Capilar',
      'Keratina',
      'Botox Capilar',
      'Hidratación',
    ],
  },
  {
    id: 'unas',
    nombre: 'Uñas',
    icon: '💅',
    servicios_sugeridos: [
      'Manicura',
      'Pedicura',
      'Uñas Acrílicas',
      'Uñas de Gel',
    ],
  },
  {
    id: 'facial',
    nombre: 'Faciales',
    icon: '🧖',
    servicios_sugeridos: [
      'Limpieza Facial',
      'Mascarilla',
      'Exfoliación',
      'Masaje Facial',
    ],
  },
  {
    id: 'maquillaje',
    nombre: 'Maquillaje',
    icon: '💄',
    servicios_sugeridos: [
      'Maquillaje Social',
      'Maquillaje de Novia',
      'Maquillaje Profesional',
      'Cejas y Pestañas',
    ],
  },
  {
    id: 'masajes',
    nombre: 'Masajes',
    icon: '🙌',
    servicios_sugeridos: [
      'Masaje Relajante',
      'Masaje Terapéutico',
      'Masaje con Piedras',
      'Masaje Descontracturante',
    ],
  },
  {
    id: 'depilacion',
    nombre: 'Depilación',
    icon: '✨',
    servicios_sugeridos: [
      'Depilación con Cera',
      'Depilación Láser',
      'Depilación Facial',
      'Depilación Corporal',
    ],
  },
];

const categoriaServicioSchema = z.object({
  usuario_id: z.string().min(1),
  nombre: z.string().min(1),
  descripcion: z.string().optional(),
});

const normalizarNombre = (s: string) => s.trim().toLowerCase();

// Inicializar catálogo (ejecutar una sola vez)
export const inicializarCatalogo = async (req: Request, res: Response): Promise<void> => {
  try {
    const batch = db.batch();

    CATEGORIAS_CATALOGO.forEach((categoria) => {
      const ref = db.collection('categorias_servicio').doc(categoria.id);
      batch.set(ref, {
        ...categoria,
        activo: true,
        fecha_creacion: FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();

    res.status(200).json({
      message: 'Catálogo de categorías inicializado correctamente',
      categorias: CATEGORIAS_CATALOGO.length,
    });
  } catch (error: any) {
    console.error('Error inicializando catálogo:', error);
    res.status(500).json({ error: error.message });
  }
};

// Crear categoría de servicio
export const createCategoriaServicio = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = categoriaServicioSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }

    const { usuario_id, nombre, descripcion } = parsed.data;
    const nombre_normalizado = normalizarNombre(nombre);

    // Verificar duplicado: misma categoría para el mismo usuario
    const dupSnap = await db
      .collection("categorias_servicio")
      .where("usuario_id", "==", usuario_id)
      .where("nombre_normalizado", "==", nombre_normalizado)
      .limit(1)
      .get();

    if (!dupSnap.empty) {
      res.status(409).json({ error: "Ya existe una categoría con ese nombre para este usuario." });
      return;
    }

    const payload = {
      usuario_id,
      nombre,
      nombre_normalizado,
      descripcion: descripcion ?? null,
      fecha_creacion: FieldValue.serverTimestamp(),
      fecha_actualizacion: FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection("categorias_servicio").add(payload);
    res.status(201).json({ id: docRef.id, usuario_id, nombre, descripcion: descripcion ?? null });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener todas las categorías de servicio
export const getCategoriasServicio = async (_req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection("categorias_servicio").get();
    const categorias: CategoriaServicio[] = snapshot.docs.map(
      (doc) => ({ id: doc.id, ...doc.data() } as CategoriaServicio)
    );
    res.json(categorias);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener categoría de servicio por ID
export const getCategoriaServicioById = async (req: Request, res: Response): Promise<void> => {
  try {
    const doc = await db.collection("categorias_servicio").doc(req.params.id).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Categoría no encontrada" });
      return;
    }
    res.json({ id: doc.id, ...doc.data() } as CategoriaServicio);
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Actualizar categoría de servicio
export const updateCategoriaServicio = async (req: Request, res: Response): Promise<void> => {
  try {
    const parsed = categoriaServicioSchema.partial().safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.issues });
      return;
    }

    const updates: any = { ...parsed.data, fecha_actualizacion: FieldValue.serverTimestamp() };
    if (updates.nombre) {
      updates.nombre_normalizado = normalizarNombre(updates.nombre);
    }

    // (Opcional) validar duplicado en update si cambian nombre/usuario_id
    if (updates.nombre || updates.usuario_id) {
      const current = await db.collection("categorias_servicio").doc(req.params.id).get();
      if (current.exists) {
        const currData = current.data()!;
        const usuarioIdCheck = updates.usuario_id ?? currData.usuario_id;
        const nombreNormCheck = updates.nombre
          ? normalizarNombre(updates.nombre)
          : currData.nombre_normalizado;

        const dupSnap = await db
          .collection("categorias_servicio")
          .where("usuario_id", "==", usuarioIdCheck)
          .where("nombre_normalizado", "==", nombreNormCheck)
          .limit(1)
          .get();

        // si existe otro documento distinto con el mismo par (usuario_id, nombre_normalizado)
        if (!dupSnap.empty && dupSnap.docs[0].id !== req.params.id) {
          res.status(409).json({ error: "Ya existe una categoría con ese nombre para este usuario." });
          return;
        }
      }
    }

    await db.collection("categorias_servicio").doc(req.params.id).update(updates);
    res.json({ message: "Categoría actualizada" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Eliminar categoría de servicio
export const deleteCategoriaServicio = async (req: Request, res: Response): Promise<void> => {
  try {
    await db.collection("categorias_servicio").doc(req.params.id).delete();
    res.json({ message: "Categoría eliminada" });
    return;
  } catch (error: any) {
    res.status(500).json({ error: error.message });
    return;
  }
};

// Obtener todas las categorías
export const getCategorias = async (req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await db.collection('categorias_servicio')
      .where('activo', '==', true)
      .get();

    const categorias = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.status(200).json(categorias);
  } catch (error: any) {
    console.error('Error obteniendo categorías:', error);
    res.status(500).json({ error: error.message });
  }
};

// Obtener una categoría por ID
export const getCategoriaById = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const doc = await db.collection('categorias_servicio').doc(id).get();

    if (!doc.exists) {
      res.status(404).json({ error: 'Categoría no encontrada' });
      return;
    }

    res.status(200).json({
      id: doc.id,
      ...doc.data(),
    });
  } catch (error: any) {
    console.error('Error obteniendo categoría:', error);
    res.status(500).json({ error: error.message });
  }
};
