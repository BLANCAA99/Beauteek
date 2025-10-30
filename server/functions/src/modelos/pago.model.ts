export interface Pago {
  id?: string;
  cita_id: string;
  metodo: string;
  monto: number;
  moneda: string;
  estado: string;
  fecha_pago?: string;
  referencia_ext?: string;
}