export interface Resena {
  id?: string;
  usuario_salon_id: string;
  usuario_cliente_id: string;
  comercio_id: string; // ID del comercio/sucursal específica
  servicio_id: string;
  cita_id?: string;
  calificacion: number;
  comentario?: string;
  foto_url?: string;
  fecha: string;
  fecha_creacion?: any;
}