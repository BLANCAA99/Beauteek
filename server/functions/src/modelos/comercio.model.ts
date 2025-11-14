import { z } from 'zod';
import { Timestamp } from 'firebase-admin/firestore';

// Interface para GeoPoint
export interface GeoPoint {
  _latitude: number;
  _longitude: number;
}

// Interface principal para Comercio
export interface Comercio {
  id?: string;
  id_documento: string;
  uid_cliente_propietario: string;
  uid_negocio: string;
  nombre: string;
  telefono: string;
  email: string;
  rtn: string;
  cuenta_bancaria_id?: string;
  sucursal_principal_id?: string;
  estado: "paso1_completado" | "paso2_completado" | "paso3_completado" | "activo" | "inactivo" | "suspendido";
  fecha_creacion?: Timestamp;
  fecha_actualizacion?: Timestamp;
  fecha_activacion?: Timestamp;
  ubicacion?: GeoPoint;
  foto_url?: string;
  descripcion?: string;
  calificacion?: number;
}

// Interface para Sucursal
export interface Sucursal {
  id?: string;
  comercio_id: string;
  nombre: string;
  direccion: string;
  telefono_sucursal?: string;
  geo: GeoPoint;
  es_principal: boolean;
  estado: "activo" | "inactivo";
  fecha_creacion?: Timestamp;
  fecha_actualizacion?: Timestamp;
}

// Interface para respuesta de búsqueda cercana
export interface ComercioDestacado {
  id: string;
  comercio_id: string;
  nombre: string;
  telefono: string;
  email: string;
  foto_url: string;
  descripcion?: string;
  calificacion: number;
  distancia: number;
  sucursal_id?: string;
  sucursal_nombre?: string;
  direccion?: string;
  geo: GeoPoint;
  es_principal?: boolean;
}

// Zod Schema - Comercio completo
export const comercioSchema = z.object({
  id_documento: z.string().optional(),
  uid_cliente_propietario: z.string().optional(),
  uid_negocio: z.string().optional(),
  nombre: z.string().min(3, "La razón social es requerida."),
  telefono: z.string().min(8, "El teléfono debe tener al menos 8 dígitos."),
  email: z.string().email("Email inválido"),
  rtn: z.string().length(14, "El RTN debe tener 14 dígitos").optional(),
  cuenta_bancaria_id: z.string().optional(),
  sucursal_principal_id: z.string().optional(),
  estado: z.enum(['paso1_completado', 'paso2_completado', 'paso3_completado', 'activo', 'inactivo', 'suspendido']),
  ubicacion: z.object({
    _latitude: z.number().min(-90).max(90),
    _longitude: z.number().min(-180).max(180),
  }).optional(),
  foto_url: z.string().url().optional(),
  descripcion: z.string().max(500).optional(),
  calificacion: z.number().min(0).max(5).optional(),
});

// Zod Schema - Crear Comercio
export const createComercioSchema = z.object({
  id_documento: z.string().optional(),
  uid_cliente_propietario: z.string().optional(),
  uid_negocio: z.string().optional(),
  nombre: z.string().min(3, "La razón social es requerida."),
  telefono: z.string().min(8, "El teléfono debe tener al menos 8 dígitos."),
  email: z.string().email("Email inválido"),
  rtn: z.string().length(14, "El RTN debe tener 14 dígitos"),
  estado: z.enum(['paso1_completado', 'paso2_completado', 'paso3_completado', 'activo', 'inactivo', 'suspendido']),
  admin_salon: z.object({
    email: z.string().email(),
    password: z.string().min(6, "La contraseña debe tener al menos 6 caracteres"),
  }),
});

// Zod Schema - Actualizar Comercio
export const updateComercioSchema = comercioSchema.partial();

// Zod Schema - Parámetros de búsqueda cercana
export const searchNearbySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radio: z.coerce.number().min(1).max(100).optional().default(50),
});

export type SearchNearbyParams = z.infer<typeof searchNearbySchema>;
