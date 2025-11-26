import { Router, Request, Response } from 'express';
import { db } from '../config/firebase';
import { verifyToken } from '../middleware/auth.middleware';

const router = Router();

// Reporte de datos del salón (ingresos, servicios, clientes, citas canceladas)
router.get('/salon/:comercioId', verifyToken, async (req: Request, res: Response) => {
  try {
    const { comercioId } = req.params;
    const { periodo = 'Semana' } = req.query;

    // Calcular fecha de inicio según el periodo
    const ahora = new Date();
    let fechaInicio: Date;

    switch (periodo) {
      case 'Semana':
        fechaInicio = new Date(ahora.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'Mes':
        fechaInicio = new Date(ahora.getFullYear(), ahora.getMonth() - 1, ahora.getDate());
        break;
      case 'Año':
        fechaInicio = new Date(ahora.getFullYear() - 1, ahora.getMonth(), ahora.getDate());
        break;
      default:
        fechaInicio = new Date(ahora.getTime() - 7 * 24 * 60 * 60 * 1000);
    }

    // Obtener citas del comercio (sin filtro de fecha para evitar índice compuesto)
    const citasSnapshot = await db.collection('citas')
      .where('comercio_id', '==', comercioId)
      .get();

    // Filtrar por fecha en memoria
    const citas = citasSnapshot.docs
      .map(doc => ({ id: doc.id, ...doc.data() }))
      .filter((cita: any) => {
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
    const { periodo = 'Semana' } = req.query;

    // Calcular fecha de inicio según el periodo
    const ahora = new Date();
    let fechaInicio: Date;

    switch (periodo) {
      case 'Semana':
        fechaInicio = new Date(ahora.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'Mes':
        fechaInicio = new Date(ahora.getFullYear(), ahora.getMonth() - 1, ahora.getDate());
        break;
      case 'Año':
        fechaInicio = new Date(ahora.getFullYear() - 1, ahora.getMonth(), ahora.getDate());
        break;
      default:
        fechaInicio = new Date(ahora.getTime() - 7 * 24 * 60 * 60 * 1000);
    }

    // Obtener citas del cliente (sin filtro de fecha para evitar índice compuesto)
    const citasSnapshot = await db.collection('citas')
      .where('cliente_id', '==', clienteId)
      .get();

    // Filtrar por fecha en memoria
    const citas = citasSnapshot.docs
      .map(doc => ({ id: doc.id, ...doc.data() }))
      .filter((cita: any) => {
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
      const comercioNombre = cita.comercio_nombre || 'Salón';
      const estado = cita.estado;
      const precio = parseFloat(cita.precio || 0);
      const servicioNombre = cita.servicio_nombre || 'Desconocido';
      const fechaHora = cita.fecha_hora?.toDate ? cita.fecha_hora.toDate() : new Date(cita.fecha_hora);

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

export default router;
