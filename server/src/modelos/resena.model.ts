export interface Resena {
  id?: string;
  usuario_salon_id: string;
  usuario_cliente_id: string;
  servicio_id: string;
  calificacion: number;
  comentario?: string;
  fecha: string;
}