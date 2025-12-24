export interface Pago {
  id?: string;
  cita_id: string;
  metodo: string;
  monto: number; // Monto total que paga el cliente
  monto_comision?: number; // Comisión que retiene Beauteek (5%)
  monto_salon?: number; // Monto que recibe el salón (95%)
  porcentaje_comision?: number; // Porcentaje de comisión aplicado (5)
  moneda: string;
  estado: string;
  fecha_pago?: string;
  referencia_ext?: string;
}