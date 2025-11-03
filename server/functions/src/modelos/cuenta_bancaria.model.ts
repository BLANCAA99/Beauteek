import { z } from 'zod';
import { FieldValue } from 'firebase-admin/firestore';

export interface CuentaBancaria {
  id?: string;
  comercio_id: string;
  banco: string;
  numero_cuenta: string;
  tipo_cuenta: 'AHORRO' | 'CHEQUES';
  nombre_titular: string;
  creado_en?: FieldValue;
}

export const cuentaBancariaSchema = z.object({
  comercio_id: z.string(),
  banco: z.string(),
  numero_cuenta: z.string(),
  tipo_cuenta: z.enum(['AHORRO', 'CHEQUES']),
  nombre_titular: z.string(),
});

export const updateCuentaBancariaSchema = cuentaBancariaSchema.partial();

export function enmascararCuenta(numero: string): string {
  if (numero.length <= 4) return numero;
  return `****${numero.slice(-4)}`;
}
