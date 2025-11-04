import { z } from 'zod';

export interface Tarjeta {
  id?: string;
  id_documento: string;
  usuario_id: string;
  
  // Información de la tarjeta
  numero_tarjeta_ultimos4: string; // Solo guardamos últimos 4 dígitos
  nombre_titular: string;
  fecha_expiracion: string; // MM/YY
  tipo: 'debito' | 'credito';
  banco: string;
  
  // Estado
  activa: boolean;
  es_principal: boolean;
  verificada: boolean;
  
  // Timestamps
  fecha_creacion?: any;
  fecha_actualizacion?: any;
}

export const tarjetaSchema = z.object({
  numero_tarjeta: z.string().length(16, "El número de tarjeta debe tener 16 dígitos").regex(/^\d+$/, "Solo números"),
  nombre_titular: z.string().min(3, "El nombre del titular es requerido"),
  fecha_expiracion: z.string().regex(/^(0[1-9]|1[0-2])\/\d{2}$/, "Formato debe ser MM/YY"),
  cvv: z.string().length(3, "El CVV debe tener 3 dígitos").regex(/^\d+$/, "Solo números"),
  tipo: z.enum(['debito', 'credito'] as const),
  banco: z.string().min(1, "El banco es requerido"),
});

export const updateTarjetaSchema = tarjetaSchema.partial();
