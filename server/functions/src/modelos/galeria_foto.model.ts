import { z } from 'zod';

export const GaleriaFotoSchema = z.object({
  id: z.string().optional(),
  comercio_id: z.string().min(1, 'El comercio_id es obligatorio'),
  servicio_id: z.string().optional(),
  servicio_nombre: z.string().optional(),
  foto_url: z
    .string()
    .min(1, 'La foto_url es obligatoria')
    .url('Debe ser una URL válida'),
  descripcion: z.string().optional(),
  fecha_creacion: z.date().optional(),
});

export type GaleriaFoto = z.infer<typeof GaleriaFotoSchema>;
