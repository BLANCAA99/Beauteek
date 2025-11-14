export interface Servicio {
  id?: string;
  usuario_id: string;
  comercio_id: string;
  categoria_id: string;
  nombre: string;
  descripcion?: string | null;
  duracion_min: number;
  precio: number;
  moneda: string;
  activo: boolean;
  fecha_creacion?: any;
}