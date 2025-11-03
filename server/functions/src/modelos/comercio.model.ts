import { z } from 'zod';
import { GeoPoint } from 'firebase-admin/firestore';

export interface Comercio {
  id?: string;
  id_documento: string;
  uid_cliente_propietario: string;
  uid_negocio: string;
  
  // Información básica
  nombre: string;
  telefono: string;
  email: string;
  
  // Ubicación (SOLO en comercios, no en usuarios)
  direccion?: string;
  geo?: GeoPoint;
  
  // Estado del proceso de registro
  estado: "paso1_completado" | "paso2_completado" | "activo" | "inactivo" | "suspendido";
  
  // Timestamps
  fecha_creacion?: any;
  fecha_actualizacion?: any;
  fecha_activacion?: any;
}

export const comercioSchema = z.object({
  id_documento: z.string().optional(),
  uid_cliente_propietario: z.string().optional(),
  uid_negocio: z.string().optional(),
  nombre: z.string().min(3, "La razón social es requerida."),
  telefono: z.string().min(8, "El teléfono debe tener al menos 8 dígitos."),
  email: z.string().email(),
  direccion: z.string().optional(),
  geo: z.object({
    lat: z.number(),
    lng: z.number(),
  }).optional(),
  estado: z.enum(['paso1_completado', 'paso2_completado', 'activo', 'inactivo', 'suspendido']),
});

export const createComercioSchema = z.object({
  id_documento: z.string().optional(),
  uid_cliente_propietario: z.string().optional(), // Opcional, para flujos donde el propietario ya existe
  uid_negocio: z.string().optional(),
  nombre: z.string().min(3, "La razón social es requerida."),
  telefono: z.string().min(8, "El teléfono debe tener al menos 8 dígitos."),
  email: z.string().email(),
  direccion: z.string().optional(),
  geo: z.object({
    lat: z.number(),
    lng: z.number(),
  }).optional(),
  estado: z.enum(['paso1_completado', 'paso2_completado', 'activo', 'inactivo', 'suspendido']),
  admin_salon: z.object({
    email: z.string().email(),
    password: z.string().min(6),
  }),
});

// Esquema para actualizar un comercio (hace todos los campos opcionales)
export const updateComercioSchema = comercioSchema.partial();

// Puedes añadir más exportaciones si es necesario
