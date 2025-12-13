import { Router, Request, Response } from 'express';
import { db } from '../config/firebase';
import { verifyToken } from '../middleware/auth.middleware';

const router = Router();

// Reporte de datos del salón (ingresos, servicios, clientes, citas canceladas)
router.get('/salon/:comercioId', verifyToken, async (req: Request, res: Response) => {
  try {
    const { comercioId } = req.params;
    const { periodo = 'Todos' } = req.query;

    // Calcular fecha de inicio según el periodo
    const ahora = new Date();
    let fechaInicio: Date;
    let filtrarPorFecha = true;

    switch (periodo) {
      case 'Todos':
        // No filtrar por fecha, traer todas las citas
        filtrarPorFecha = false;
        fechaInicio = new Date(0); // Fecha muy antigua
        break;
      case 'Mes':
        fechaInicio = new Date(ahora.getFullYear(), ahora.getMonth(), 1); // Primer día del mes actual
        break;
      case 'Año':
        fechaInicio = new Date(ahora.getFullYear(), 0, 1); // 1 de enero del año actual
        break;
      default:
        filtrarPorFecha = false;
        fechaInicio = new Date(0);
    }

    // Obtener citas del comercio (sin filtro de fecha para evitar índice compuesto)
    const citasSnapshot = await db.collection('citas')
      .where('comercio_id', '==', comercioId)
      .get();

    // Filtrar por fecha en memoria (si aplica)
    const citas = citasSnapshot.docs
      .map(doc => ({ id: doc.id, ...doc.data() }))
      .filter((cita: any) => {
        if (!filtrarPorFecha) return true; // Si es "Todos", no filtrar
        const fechaCita = cita.fecha_hora?.toDate ? cita.fecha_hora.toDate() : new Date(cita.fecha_hora);
        return fechaCita >= fechaInicio;
      }) as any[];

    // Procesar datos
    let ingresosTotales = 0;
    const clientesUnicos = new Set<string>();
    const serviciosContador: { [key: string]: number } = {};
    let citasCanceladas = 0;
    let nuevosClientes = 0;
    const hace30Dias = new Date(ahora.getTime() - 30 * 24 * 60 * 60 * 1000);
    const clientesDetalles: any[] = [];
    const clientesMap = new Map<string, any>();

    for (const cita of citas) {
      const clienteId = cita.cliente_id;
      const estado = cita.estado;
      const precio = parseFloat(cita.precio || 0);
      const servicioNombre = cita.servicio_nombre || 'Desconocido';
      const fechaHora = cita.fecha_hora?.toDate ? cita.fecha_hora.toDate() : new Date(cita.fecha_hora);

      // Clientes únicos
      if (clienteId) {
        clientesUnicos.add(clienteId);

        if (!clientesMap.has(clienteId)) {
          clientesMap.set(clienteId, {
            cliente_id: clienteId,
            nombre: cita.cliente_nombre || 'Cliente',
            total_citas: 1,
            primera_cita: fechaHora,
            ultima_cita: fechaHora,
            servicios: [servicioNombre]
          });

          // Verificar si es nuevo cliente (primera cita hace menos de 30 días)
          if (fechaHora >= hace30Dias) {
            nuevosClientes++;
          }
        } else {
          const cliente = clientesMap.get(clienteId);
          cliente.total_citas++;
          if (fechaHora > cliente.ultima_cita) {
            cliente.ultima_cita = fechaHora;
          }
          if (fechaHora < cliente.primera_cita) {
            cliente.primera_cita = fechaHora;
          }
          if (!cliente.servicios.includes(servicioNombre)) {
            cliente.servicios.push(servicioNombre);
          }
        }
      }

      // Ingresos (solo citas completadas)
      if (estado === 'completada') {
        ingresosTotales += precio;
      }

      // Citas canceladas
      if (estado === 'cancelada') {
        citasCanceladas++;
      }

      // Servicios populares
      serviciosContador[servicioNombre] = (serviciosContador[servicioNombre] || 0) + 1;
    }

    // Convertir clientes map a array
    clientesDetalles.push(...Array.from(clientesMap.values()));

    // Ordenar servicios por popularidad
    const serviciosPopulares = Object.entries(serviciosContador)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([nombre, cantidad]) => ({ nombre, cantidad }));

    // Respuesta
    res.json({
      periodo,
      fechaInicio,
      fechaFin: ahora,
      totalClientes: clientesUnicos.size,
      nuevosClientes,
      ingresosTotales: parseFloat(ingresosTotales.toFixed(2)),
      citasCanceladas,
      totalCitas: citas.length,
      serviciosPopulares,
      clientes: clientesDetalles.sort((a, b) => b.total_citas - a.total_citas)
    });

  } catch (error) {
    console.error('Error generando reporte de salón:', error);
    res.status(500).json({ error: 'Error al generar el reporte' });
  }
});

// Reporte de cliente (historial de citas, gastos, salones visitados)
router.get('/cliente/:clienteId', verifyToken, async (req: Request, res: Response) => {
  try {
    const { clienteId } = req.params;
    const { periodo = 'Todos' } = req.query;

    // Calcular fecha de inicio según el periodo
    const ahora = new Date();
    let fechaInicio: Date;
    let filtrarPorFecha = true;

    switch (periodo) {
      case 'Todos':
        // No filtrar por fecha, traer todas las citas
        filtrarPorFecha = false;
        fechaInicio = new Date(0); // Fecha muy antigua
        break;
      case 'Mes':
        fechaInicio = new Date(ahora.getFullYear(), ahora.getMonth(), 1); // Primer día del mes actual
        break;
      case 'Año':
        fechaInicio = new Date(ahora.getFullYear(), 0, 1); // 1 de enero del año actual
        break;
      default:
        filtrarPorFecha = false;
        fechaInicio = new Date(0);
    }

    // Obtener citas del cliente (sin filtro de fecha para evitar índice compuesto)
    const citasSnapshot = await db.collection('citas')
      .where('usuario_cliente_id', '==', clienteId)
      .get();

    // Filtrar por fecha en memoria (si aplica)
    const citas = citasSnapshot.docs
      .map(doc => ({ id: doc.id, ...doc.data() }))
      .filter((cita: any) => {
        if (!filtrarPorFecha) return true; // Si es "Todos", no filtrar
        const fechaCita = cita.fecha_hora?.toDate ? cita.fecha_hora.toDate() : new Date(cita.fecha_hora);
        return fechaCita >= fechaInicio;
      }) as any[];

    // Procesar datos
    let gastoTotal = 0;
    const salonesVisitados = new Set<string>();
    const serviciosRecibidos: { [key: string]: number } = {};
    let citasCompletadas = 0;
    let citasCanceladas = 0;
    const salonesMap = new Map<string, any>();
    const citasDetalles: any[] = [];

    for (const cita of citas) {
      const comercioId = cita.comercio_id;
      let comercioNombre = cita.comercio_nombre || 'Salón';
      const estado = cita.estado;
      const precio = parseFloat(cita.precio || 0);
      const servicioNombre = cita.servicio_nombre || 'Desconocido';
      const fechaHora = cita.fecha_hora?.toDate ? cita.fecha_hora.toDate() : new Date(cita.fecha_hora);

      // Obtener nombre del comercio si no viene en la cita
      if (comercioId && (!cita.comercio_nombre || cita.comercio_nombre === 'Salón')) {
        try {
          const comercioDoc = await db.collection('comercios').doc(comercioId).get();
          if (comercioDoc.exists) {
            comercioNombre = comercioDoc.data()?.nombre || comercioNombre;
          }
        } catch (e) {
          console.warn(`No se pudo obtener nombre del comercio ${comercioId}`);
        }
      }

      // Salones visitados
      if (comercioId) {
        salonesVisitados.add(comercioId);

        if (!salonesMap.has(comercioId)) {
          salonesMap.set(comercioId, {
            comercio_id: comercioId,
            nombre: comercioNombre,
            visitas: 1,
            gasto_total: estado === 'completada' ? precio : 0
          });
        } else {
          const salon = salonesMap.get(comercioId);
          salon.visitas++;
          if (estado === 'completada') {
            salon.gasto_total += precio;
          }
        }
      }

      // Gastos (solo citas completadas)
      if (estado === 'completada') {
        gastoTotal += precio;
        citasCompletadas++;
      }

      // Citas canceladas
      if (estado === 'cancelada') {
        citasCanceladas++;
      }

      // Servicios recibidos
      serviciosRecibidos[servicioNombre] = (serviciosRecibidos[servicioNombre] || 0) + 1;

      // Agregar detalle de cita
      citasDetalles.push({
        id: cita.id,
        salon: comercioNombre,
        servicio: servicioNombre,
        fecha: fechaHora,
        precio,
        estado
      });
    }

    // Ordenar servicios por frecuencia
    const serviciosFrecuentes = Object.entries(serviciosRecibidos)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([nombre, cantidad]) => ({ nombre, cantidad }));

    // Respuesta
    res.json({
      periodo,
      fechaInicio,
      fechaFin: ahora,
      totalCitas: citas.length,
      citasCompletadas,
      citasCanceladas,
      gastoTotal: parseFloat(gastoTotal.toFixed(2)),
      salonesVisitados: salonesVisitados.size,
      serviciosFrecuentes,
      salones: Array.from(salonesMap.values()).sort((a, b) => b.visitas - a.visitas),
      citas: citasDetalles.sort((a, b) => b.fecha.getTime() - a.fecha.getTime())
    });

  } catch (error) {
    console.error('Error generando reporte de cliente:', error);
    res.status(500).json({ error: 'Error al generar el reporte' });
  }
});

// Reporte de gastos por salón (para ayudar al cliente a decidir dónde agendar)
router.get('/cliente/:clienteId/gastos-por-salon', verifyToken, async (req: Request, res: Response) => {
  try {
    const { clienteId } = req.params;

    // Obtener todas las citas completadas del cliente
    const citasSnapshot = await db.collection('citas')
      .where('usuario_cliente_id', '==', clienteId)
      .where('estado', '==', 'completada')
      .get();

    const citas = citasSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as any[];

    const ahora = new Date();
    const primerDiaMesActual = new Date(ahora.getFullYear(), ahora.getMonth(), 1);
    const primerDiaAnioActual = new Date(ahora.getFullYear(), 0, 1);

    // Agrupar por salón
    const salonesMap = new Map<string, any>();

    for (const cita of citas) {
      const comercioId = cita.comercio_id;
      let comercioNombre = cita.comercio_nombre || 'Salón';
      const precio = parseFloat(cita.precio || 0);
      const fechaHora = cita.fecha_hora?.toDate ? cita.fecha_hora.toDate() : new Date(cita.fecha_hora);

      if (!comercioId) continue;

      // Obtener nombre del comercio si no viene en la cita
      if (!salonesMap.has(comercioId)) {
        try {
          const comercioDoc = await db.collection('comercios').doc(comercioId).get();
          if (comercioDoc.exists) {
            comercioNombre = comercioDoc.data()?.nombre || comercioNombre;
          }
        } catch (e) {
          console.warn(`No se pudo obtener nombre del comercio ${comercioId}`);
        }

        salonesMap.set(comercioId, {
          comercio_id: comercioId,
          nombre: comercioNombre,
          gasto_total: 0,
          gasto_mes: 0,
          gasto_anio: 0,
          citas_total: 0,
          citas_mes: 0,
          citas_anio: 0
        });
      }

      const salon = salonesMap.get(comercioId);
      
      // Total (todas las citas completadas)
      salon.gasto_total += precio;
      salon.citas_total++;

      // Mes actual
      if (fechaHora >= primerDiaMesActual) {
        salon.gasto_mes += precio;
        salon.citas_mes++;
      }

      // Año actual
      if (fechaHora >= primerDiaAnioActual) {
        salon.gasto_anio += precio;
        salon.citas_anio++;
      }
    }

    // Convertir a array y ordenar por gasto total
    const salonesConGastos = Array.from(salonesMap.values())
      .map(salon => ({
        ...salon,
        gasto_total: parseFloat(salon.gasto_total.toFixed(2)),
        gasto_mes: parseFloat(salon.gasto_mes.toFixed(2)),
        gasto_anio: parseFloat(salon.gasto_anio.toFixed(2))
      }))
      .sort((a, b) => b.gasto_total - a.gasto_total);

    res.json({
      salones: salonesConGastos,
      resumen: {
        total_salones: salonesConGastos.length,
        gasto_total_general: parseFloat(salonesConGastos.reduce((sum, s) => sum + s.gasto_total, 0).toFixed(2)),
        gasto_mes_general: parseFloat(salonesConGastos.reduce((sum, s) => sum + s.gasto_mes, 0).toFixed(2)),
        gasto_anio_general: parseFloat(salonesConGastos.reduce((sum, s) => sum + s.gasto_anio, 0).toFixed(2))
      }
    });

  } catch (error) {
    console.error('Error generando reporte de gastos por salón:', error);
    res.status(500).json({ error: 'Error al generar el reporte' });
  }
});

export default router;
