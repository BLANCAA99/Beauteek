import { z } from 'zod';

// Esquema para validar la actualización de un comercio.
// Hacemos los campos opcionales porque en una actualización (PUT/PATCH)
// no siempre se envían todos los campos.
export const updateComercioSchema = z.object({
  nombre: z.string().min(1, "El nombre no puede estar vacío.").optional(),
  telefono: z.string().optional(),
  activo: z.boolean().optional(),
}).strict();
