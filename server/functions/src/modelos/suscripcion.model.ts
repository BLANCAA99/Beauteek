export interface Suscripcion {
  id?: string;
  uid_negocio: string; // UID del dueño del salón
  comercio_id: string; // ID del comercio/salón
  tarjeta_id: string; // ID de la tarjeta a usar para cobros
  plan: 'mensual'; // Tipo de plan (plan único de L 275)
  estado: 'activa' | 'suspendida' | 'cancelada'; // Estado de la suscripción
  precio_mensual: number; // Precio del plan (275 lempiras)
  fecha_inicio: string; // Fecha de inicio de suscripción
  fecha_proximo_cobro?: string; // Próxima fecha de cobro
  fecha_cancelacion?: string; // Fecha de cancelación (si aplica)
  fecha_creacion?: string; // Timestamp de creación
  fecha_actualizacion?: string; // Timestamp de última actualización
}

export interface SuscripcionCreateDTO {
  uid_negocio: string;
  comercio_id: string;
  tarjeta_id: string;
  plan: 'mensual';
  precio_mensual: number;
}

export interface SuscripcionUpdateDTO {
  tarjeta_id?: string;
  plan?: 'mensual';
  estado?: 'activa' | 'suspendida' | 'cancelada';
  precio_mensual?: number;
}

// Historial de cambios de tarjeta
export interface HistorialTarjeta {
  id?: string;
  suscripcion_id: string;
  uid_negocio_anterior?: string; // UID del dueño anterior
  uid_negocio_nuevo: string; // UID del nuevo dueño
  tarjeta_id_anterior?: string;
  tarjeta_id_nueva: string;
  motivo: string; // "cambio_dueno", "actualizacion_tarjeta", etc.
  fecha_cambio: string;
}
