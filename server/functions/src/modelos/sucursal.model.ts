import { z } from 'zod';
import { FieldValue } from 'firebase-admin/firestore';

export interface Sucursal {
  id?: string;
  comercio_id: string;
  nombre: string;
  telefono: string;
  direccion: string;
  geo_lat: number;
  geo_lng: number;
  activa: boolean;
  creado_en?: FieldValue;
  actualizado_en?: FieldValue;
}

export const sucursalSchema = z.object({
  comercio_id: z.string().min(1, "El ID del comercio es requerido."),
  nombre: z.string().min(1, "El nombre de la sucursal es requerido."),
  telefono: z.string().min(8, "El teléfono es requerido."),
  direccion: z.string().min(1, "La dirección es requerida."),
  geo_lat: z.number(),
  geo_lng: z.number(),
  activa: z.boolean().default(true),
});

// Añade esta línea para exportar el esquema de actualización
export const updateSucursalSchema = sucursalSchema.partial();
