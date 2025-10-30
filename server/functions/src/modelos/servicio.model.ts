export interface Servicio {
  id?: string;
  usuario_id: string;
  categoria_id: string;
  nombre: string;
  descripcion?: string;
  duracion_min: number;
  precio: number;
  moneda: string;
  activo: boolean;
}