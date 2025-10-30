export interface Usuario {
  id?: string;
  nombre_completo: string;
  email: string;
  password: string;
  telefono?: string;
  rol?: string;
  foto_url?: string;
  direccion?: string;
  fecha_nacimiento?: string; // <-- AÑADIDO
  genero?: string; // <-- AÑADIDO
  geo_lat?: number;
  geo_lng?: number;
  estado?: string;
  fecha_creacion?: string;
}