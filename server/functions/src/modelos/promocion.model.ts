export interface Promocion {
  id?: string;
  comercio_id: string;
  servicio_id: string;
  servicio_nombre: string;
  foto_url?: string;
  descripcion?: string;
  tipo_descuento: string; // "porcentaje" | "monto"
  valor: number;
  precio_original?: number;
  precio_con_descuento?: number;
  fecha_inicio: string;
  fecha_fin: string;
  activo: boolean;
  fecha_creacion?: any;
  fecha_actualizacion?: any;
}