/**
 * Modelo de Personal/Colaborador
 * 
 * Representa a los empleados de un salón de belleza.
 * Este modelo permite escalabilidad futura para gestionar disponibilidad
 * y asignación de servicios por colaborador.
 * 
 * Estrategia de implementación:
 * - Fase 1 (actual): Gestión por servicios y horarios del salón
 * - Fase 2 (futura): Gestión individualizada por colaborador
 */

import { z } from 'zod';
export const personalSchema = z.object({
  comercio_id: z.string().min(1, 'El ID del comercio es requerido'),
  nombre_completo: z.string().min(1, 'El nombre completo es requerido'),
  puesto: z.string().optional(), 
  foto_url: z.string().url().optional().or(z.literal('')),
  especialidades: z.array(z.string()).optional().default([]),
  telefono: z.string().optional(),
  email: z.string().email().optional().or(z.literal('')),
  horarios_disponibles: z.array(z.object({
    dia: z.enum(['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo']),
    hora_inicio: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/),
    hora_fin: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/),
    activo: z.boolean().default(true),
  })).optional().default([]),
  estado: z.enum(['activo', 'inactivo', 'vacaciones']).default('activo'),
  comision_porcentaje: z.number().min(0).max(100).optional(),
  total_servicios_realizados: z.number().int().min(0).optional().default(0),
  calificacion_promedio: z.number().min(0).max(5).optional().default(0),
  fecha_contratacion: z.string().optional(),
  notas: z.string().optional(),
});

export type Personal = z.infer<typeof personalSchema>;
export const crearPersonalSchema = personalSchema.pick({
  comercio_id: true,
  nombre_completo: true,
  puesto: true,
  foto_url: true,
  telefono: true,
  email: true,
});

export const actualizarPersonalSchema = personalSchema.partial().required({
  comercio_id: true,
});

export const asignacionServicioSchema = z.object({
  personal_id: z.string().min(1),
  servicio_id: z.string().min(1),
  nivel_experiencia: z.enum(['junior', 'intermedio', 'senior', 'master']).optional(),
  fecha_certificacion: z.string().optional(),
});

export type AsignacionServicio = z.infer<typeof asignacionServicioSchema>;

export interface DisponibilidadPersonal {
  personal_id: string;
  fecha: string; 
  hora_inicio: string; 
  hora_fin: string;
  disponible: boolean;
  motivo?: string;
}
