export interface Ubicacion {
  uid_usuario: string; // UID del cliente o uid_negocio del salón
  tipo_entidad: 'cliente' | 'salon'; // Tipo de entidad
  es_principal: boolean; // Si es la ubicación principal
  pais: string; 
  ciudad?: string; 
  direccion_completa?: string; 
  lat: number;
  lng: number; 
  alias?: string; 
  fecha_creacion: FirebaseFirestore.Timestamp;
  fecha_actualizacion: FirebaseFirestore.Timestamp;
  activo: boolean; // Para soft-delete
}

export interface UbicacionCreateDTO {
  uid_usuario: string;
  tipo_entidad: 'cliente' | 'salon';
  es_principal?: boolean;
  pais: string;
  ciudad?: string;
  direccion_completa?: string;
  lat: number;
  lng: number;
  alias?: string;
}

export interface UbicacionUpdateDTO {
  pais?: string;
  ciudad?: string;
  direccion_completa?: string;
  lat?: number;
  lng?: number;
  alias?: string;
  es_principal?: boolean;
  activo?: boolean;
}
