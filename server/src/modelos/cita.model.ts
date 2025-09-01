export interface Cita {
  id?: string;
  usuario_salon_id: string;
  servicio_id: string;
  usuario_cliente_id: string;
  fecha_inicio: string;
  fecha_fin: string;
  estado: string;
  notas?: string;
  origen?: string;
  created_at?: string;
}