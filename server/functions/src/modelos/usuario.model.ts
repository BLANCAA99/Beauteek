export interface Usuario {
  id?: string;
  uid: string;
  nombre_completo: string;
  email: string;
  telefono?: string;
  rol?: "cliente" | "salon";
  foto_url?: string;
  direccion?: string;
  fecha_nacimiento?: string;
  rtn?: string;
  razon_social?: string;
  banco_id?: string;
  cuenta_bancaria?: string;
  tipo_cuenta?: "ahorro" | "corriente";
  verificacion_bancaria_status?: "pending" | "verified" | "rejected";
  fecha_creacion?: any;
  fecha_actualizacion?: any;
}