export interface Usuario {
  id?: string;
  nombre_completo: string;
  email: string;
  telefono?: string;
  rol?: string;
  foto_url?: string;
  direccion?: string;
  geo_lat?: number;
  geo_lng?: number;
  estado?: string;
  fecha_creacion?: string;
}