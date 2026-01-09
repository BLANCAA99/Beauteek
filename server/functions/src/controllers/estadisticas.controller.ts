import { Request, Response } from "express";
import { db } from "../config/firebase";

interface EstadisticasSalon {
  citasHoy: number;
  ingresosHoy: number;
  citasProximos7Dias: number;
  ingresosProximos7Dias: number;
  proximosClientes: any[];
  promCitasPorDia: number;
  difCitasVsSemanaAnterior: number;
  promIngresosPorDia: number;
  difIngresosVsSemanaAnterior: number;
  serviciosTop: any[];
  nuevosClientes: number;
  calificacionPromedio: number;
  totalResenas: number;
  promocionesEfectivas: any[];
}

// Obtener estadísticas completas del salón
export const getEstadisticasSalon = async (req: Request, res: Response): Promise<void> => {
  try {
    const { comercioId } = req.params;
    
    if (!comercioId) {
      res.status(400).json({ error: "comercioId es requerido" });
      return;
    }
    
    const ahora = new Date();
    const hoyInicio = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate());
    const hoyFin = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate(), 23, 59, 59);
    const manana = new Date(hoyInicio);
    manana.setDate(manana.getDate() + 1);
    const fecha7Dias = new Date(hoyInicio);
    fecha7Dias.setDate(fecha7Dias.getDate() + 7);
    const inicioSemanaActual = new Date(hoyInicio);
    inicioSemanaActual.setDate(inicioSemanaActual.getDate() - 7);
    const inicioSemanaAnterior = new Date(inicioSemanaActual);
    inicioSemanaAnterior.setDate(inicioSemanaAnterior.getDate() - 7);
    const inicioMes = new Date(ahora.getFullYear(), ahora.getMonth(), 1);
    
    // ====== OBTENER TODAS LAS CITAS DEL COMERCIO ======
    const citasSnapshot = await db
      .collection('citas')
      .where('comercio_id', '==', comercioId)
      .get();
    
    let citasHoy = 0;
    let citasProximos7Dias = 0;
    let citasSemanaActual = 0;
    let citasSemanaAnterior = 0;
    const clientesNuevosMes = new Set<string>();
    const proximosList: any[] = [];
    const serviciosCount: Record<string, number> = {};
    const citasIds: string[] = [];
    
    citasSnapshot.forEach(doc => {
      const data = doc.data();
      const fechaCita = data.fecha_hora?.toDate ? data.fecha_hora.toDate() : new Date(data.fecha_hora);
      const servicioId = data.servicio_id || '';
      const clienteId = data.usuario_id || '';
      
      citasIds.push(doc.id);
      
      // Citas de hoy
      if (fechaCita >= hoyInicio && fechaCita <= hoyFin) {
        citasHoy++;
      }
      
      // Citas próximos 7 días (desde mañana hasta 7 días)
      if (fechaCita >= manana && fechaCita < fecha7Dias) {
        citasProximos7Dias++;
      }
      
      // Citas semana actual (últimos 7 días)
      if (fechaCita >= inicioSemanaActual && fechaCita <= ahora) {
        citasSemanaActual++;
      }
      
      // Citas semana anterior (7-14 días atrás)
      if (fechaCita >= inicioSemanaAnterior && fechaCita < inicioSemanaActual) {
        citasSemanaAnterior++;
      }
      
      // Clientes únicos este mes (para calcular nuevos clientes)
      if (fechaCita >= inicioMes && clienteId) {
        clientesNuevosMes.add(clienteId);
      }
      
      // Contar servicios más solicitados
      if (servicioId) {
        serviciosCount[servicioId] = (serviciosCount[servicioId] || 0) + 1;
      }
      
      // Próximas citas (futuras)
      if (fechaCita > ahora) {
        proximosList.push({
          ...data,
          id: doc.id,
          fecha_hora_parsed: fechaCita,
        });
      }
    });
    
    // ====== OBTENER TODOS LOS PAGOS DEL COMERCIO (INGRESOS REALES) ======
    const pagosSnapshot = await db
      .collection('pagos')
      .where('comercio_id', '==', comercioId)
      .where('estado', '==', 'completado')
      .get();
    
    let ingresosHoy = 0;
    let ingresosProximos7Dias = 0;
    let ingresosSemanaActual = 0;
    let ingresosSemanaAnterior = 0;
    
    pagosSnapshot.forEach(doc => {
      const data = doc.data();
      const fechaPago = data.fecha_pago?.toDate ? data.fecha_pago.toDate() : new Date(data.fecha_pago);
      const monto = parseFloat(data.monto || 0);
      
      // Ingresos de hoy
      if (fechaPago >= hoyInicio && fechaPago <= hoyFin) {
        ingresosHoy += monto;
      }
      
      // Ingresos próximos 7 días (proyección basada en citas programadas)
      const citaId = data.cita_id || '';
      const citaData = citasSnapshot.docs.find(c => c.id === citaId)?.data();
      if (citaData) {
        const fechaCita = citaData.fecha_hora?.toDate ? citaData.fecha_hora.toDate() : new Date(citaData.fecha_hora);
        if (fechaCita >= manana && fechaCita < fecha7Dias) {
          ingresosProximos7Dias += monto;
        }
      }
      
      // Ingresos semana actual
      if (fechaPago >= inicioSemanaActual && fechaPago <= ahora) {
        ingresosSemanaActual += monto;
      }
      
      // Ingresos semana anterior
      if (fechaPago >= inicioSemanaAnterior && fechaPago < inicioSemanaActual) {
        ingresosSemanaAnterior += monto;
      }
    });
    
    // Calcular promedios y diferencias
    const promCitasSemanaActual = citasSemanaActual / 7;
    const promCitasSemanaAnterior = citasSemanaAnterior > 0 ? citasSemanaAnterior / 7 : 0;
    const difCitas = Math.round(promCitasSemanaActual - promCitasSemanaAnterior);
    
    const promIngresosSemanaActual = ingresosSemanaActual / 7;
    const promIngresosSemanaAnterior = ingresosSemanaAnterior > 0 ? ingresosSemanaAnterior / 7 : 0;
    const difIngresos = promIngresosSemanaActual - promIngresosSemanaAnterior;
    
    // ====== OBTENER SERVICIOS TOP ======
    const serviciosSnapshot = await db
      .collection('servicios')
      .where('comercio_id', '==', comercioId)
      .get();
    
    const totalCitas = Object.values(serviciosCount).reduce((sum, count) => sum + count, 0);
    const serviciosTop: any[] = [];
    
    serviciosSnapshot.forEach(doc => {
      const data = doc.data();
      const servicioId = doc.id;
      const count = serviciosCount[servicioId] || 0;
      const porcentaje = totalCitas > 0 ? (count / totalCitas) * 100 : 0;
      
      if (count > 0) {
        serviciosTop.push({
          id: servicioId,
          nombre: data.nombre || 'Servicio',
          solicitudes: count,
          porcentaje: Math.round(porcentaje * 10) / 10,
        });
      }
    });
    
    serviciosTop.sort((a, b) => b.solicitudes - a.solicitudes);
    
    // ====== CARGAR DATOS DE CLIENTES PARA PRÓXIMAS CITAS ======
    proximosList.sort((a, b) => new Date(a.fecha_hora_parsed).getTime() - new Date(b.fecha_hora_parsed).getTime());
    const proximasTop3 = proximosList.slice(0, 3);
    
    for (const cita of proximasTop3) {
      // Obtener nombre del cliente
      if (cita.usuario_id) {
        const userDoc = await db.collection('usuarios').doc(cita.usuario_id).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          cita.nombre_cliente = userData?.nombre || 'Cliente';
        }
      }
      
      // Obtener nombre del servicio
      if (cita.servicio_id) {
        const servicioDoc = await db.collection('servicios').doc(cita.servicio_id).get();
        if (servicioDoc.exists) {
          const servicioData = servicioDoc.data();
          cita.servicio_nombre = servicioData?.nombre || 'Servicio';
        }
      }
    }
    
    // ====== OBTENER CALIFICACIÓN PROMEDIO Y TOTAL DE RESEÑAS ======
    const resenasSnapshot = await db
      .collection('resenas')
      .where('comercio_id', '==', comercioId)
      .get();
    
    let sumCalificaciones = 0;
    let totalResenas = 0;
    
    resenasSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.calificacion) {
        sumCalificaciones += parseFloat(data.calificacion);
        totalResenas++;
      }
    });
    
    const calificacionPromedio = totalResenas > 0 ? sumCalificaciones / totalResenas : 0;
    
    // ====== OBTENER PROMOCIONES MÁS EFECTIVAS ======
    const promocionesSnapshot = await db
      .collection('promociones')
      .where('comercio_id', '==', comercioId)
      .get();
    
    const promocionesEfectivas: any[] = [];
    promocionesSnapshot.forEach(doc => {
      const data = doc.data();
      const usos = citasSnapshot.docs.filter(citaDoc => 
        citaDoc.data().promocion_id === doc.id
      ).length;
      
      if (usos > 0) {
        promocionesEfectivas.push({
          id: doc.id,
          titulo: data.nombre || data.titulo || 'Promoción',
          descripcion: data.descripcion || '',
          usos: usos,
        });
      }
    });
    
    promocionesEfectivas.sort((a, b) => b.usos - a.usos);
    
    // ====== CONSTRUIR RESPUESTA ======
    const estadisticas: EstadisticasSalon = {
      citasHoy,
      ingresosHoy: Math.round(ingresosHoy * 100) / 100,
      citasProximos7Dias,
      ingresosProximos7Dias: Math.round(ingresosProximos7Dias * 100) / 100,
      proximosClientes: proximasTop3,
      promCitasPorDia: Math.round(promCitasSemanaActual * 10) / 10,
      difCitasVsSemanaAnterior: difCitas,
      promIngresosPorDia: Math.round(promIngresosSemanaActual * 100) / 100,
      difIngresosVsSemanaAnterior: Math.round(difIngresos * 100) / 100,
      serviciosTop: serviciosTop.slice(0, 3),
      nuevosClientes: clientesNuevosMes.size,
      calificacionPromedio: Math.round(calificacionPromedio * 10) / 10,
      totalResenas,
      promocionesEfectivas: promocionesEfectivas.slice(0, 1),
    };
    
    res.json(estadisticas);
  }
  catch (error: any) {
    console.error('Error obteniendo estadísticas del salón:', error);
    res.status(500).json({ error: error.message });
  }
};
