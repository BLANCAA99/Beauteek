import { z } from 'zod';
import { GeoPoint } from 'firebase-admin/firestore';

export interface Sucursal {
  id?: string;
  id_documento: string;
  comercio_id: string;
  nombre: string;
  telefono: string;
  direccion: string;
  geo?: GeoPoint; // Cambiado a GeoPoint
  es_principal: boolean; // Agregado
  estado: "activo" | "inactivo";
  fecha_creacion?: any;
  fecha_actualizacion?: any;
}

export const sucursalSchema = z.object({
  comercio_id: z.string().min(1, "El ID del comercio es requerido."),
  nombre: z.string().min(1, "El nombre de la sucursal es requerido."),
  telefono: z.string().min(8, "El teléfono es requerido."),
  direccion: z.string().min(1, "La dirección es requerida."),
  geo: z.object({
    latitude: z.number(),
    longitude: z.number(),
  }).optional(),
  es_principal: z.boolean().default(false),
  estado: z.enum(['activo', 'inactivo']).default('activo'),
});

export const updateSucursalSchema = sucursalSchema.partial();
