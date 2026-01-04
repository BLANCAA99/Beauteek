export interface CategoriaServicio {
  id?: string;
  nombre: string;
  descripcion?: string;
  icon?: string;
  activo?: boolean;
  servicios_sugeridos?: string[];
  fecha_creacion?: any;
  fecha_actualizacion?: any;
}
