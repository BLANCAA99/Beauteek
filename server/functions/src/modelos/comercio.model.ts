import { z } from 'zod';

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
  rtn: z.string().length(14, "El RTN debe tener 14 dígitos").optional(),
  cuenta_bancaria_id: z.string().optional(),
  sucursal_principal_id: z.string().optional(),
  estado: z.enum(['paso1_completado', 'paso2_completado', 'paso3_completado', 'activo', 'inactivo', 'suspendido']),
});

export const createComercioSchema = z.object({
  id_documento: z.string().optional(),
  uid_cliente_propietario: z.string().optional(),
  uid_negocio: z.string().optional(),
  nombre: z.string().min(3, "La razón social es requerida."),
  telefono: z.string().min(8, "El teléfono debe tener al menos 8 dígitos."),
  email: z.string().email(),
  rtn: z.string().length(14, "El RTN debe tener 14 dígitos"),
  estado: z.enum(['paso1_completado', 'paso2_completado', 'paso3_completado', 'activo', 'inactivo', 'suspendido']),
  admin_salon: z.object({
    email: z.string().email(),
    password: z.string().min(6),
  }),
});

export const updateComercioSchema = comercioSchema.partial();
