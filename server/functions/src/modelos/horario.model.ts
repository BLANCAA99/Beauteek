export interface Horario {
  id?: string;
  usuario_id: string;
  comercio_id: string;
  dia_semana: number;
  hora_inicio: string;
  hora_fin: string;
  activo: boolean;
  fecha_creacion?: any;
  fecha_actualizacion?: any;
}