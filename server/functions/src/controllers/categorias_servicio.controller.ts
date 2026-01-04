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
    icon: 'https://res.cloudinary.com/dskg1hw9n/image/upload/cgpakusext5dqk5zgdoq.png',
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
    icon: 'https://res.cloudinary.com/dskg1hw9n/image/upload/nhhpwj58xaymnzmp5ajt.png',
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
    icon: 'https://res.cloudinary.com/dskg1hw9n/image/upload/kaptj4lfxkomwzvo79xu.png',
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
    icon: 'https://res.cloudinary.com/dskg1hw9n/image/upload/ic3wfhzszxq1qj8j9yvq.png',
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
    icon: 'https://res.cloudinary.com/dskg1hw9n/image/upload/r2wovlxjfkgs473ouuma.png',
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
    icon: 'https://res.cloudinary.com/dskg1hw9n/image/upload/v1sgcumhazh9f9ygfaoo.png',
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
    icon: 'https://res.cloudinary.com/dskg1hw9n/image/upload/ws1ppyblzttzmqc35dkg.png',
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
    icon: 'https://res.cloudinary.com/dskg1hw9n/image/upload/gphlt3mcwmyown40ravo.png',
    servicios_sugeridos: [
      'Depilación con Cera',
      'Depilación Láser',
      'Depilación Facial',
      'Depilación Corporal',
    ],
  },
];

const categoriaServicioSchema = z.object({
  nombre: z.string().min(1),
  descripcion: z.string().optional(),
});

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

    const { nombre, descripcion } = parsed.data;

    const payload = {
      nombre,
      descripcion: descripcion ?? null,
      fecha_creacion: FieldValue.serverTimestamp(),
      fecha_actualizacion: FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection("categorias_servicio").add(payload);
    res.status(201).json({ id: docRef.id, nombre, descripcion: descripcion ?? null });
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
