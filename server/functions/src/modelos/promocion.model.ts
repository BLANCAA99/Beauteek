export interface Promocion {
  id?: string;
  usuario_id: string;
  nombre: string;
  descripcion?: string;
  tipo_descuento: string;
  valor: number;
  fecha_inicio: string;
  fecha_fin: string;
  activo: boolean;
}