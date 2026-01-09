import { Request, Response } from 'express';
import * as admin from 'firebase-admin';
const db = admin.firestore();

/**
 * Obtiene las citas de un usuario (cliente o salón) con toda la información procesada
 * Endpoint: GET /api/citas/usuario/:userId?rol=cliente|salon
 */
export const getCitasUsuario = async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const { rol } = req.query;

    let citasSnapshot;

    // Obtener citas según el rol
    if (rol === 'salon') {
      // Si es salón, buscar citas donde el usuario sea el comercio
      const comerciosSnapshot = await db.collection('comercios')
        .where('usuario_id', '==', userId)
        .limit(1)
        .get();

      if (comerciosSnapshot.empty) {
        return res.status(404).json({ error: 'Comercio no encontrado' });
      }

      const comercioId = comerciosSnapshot.docs[0].id;
      citasSnapshot = await db.collection('citas')
        .where('comercio_id', '==', comercioId)
        .get();
    } else {
      // Si es cliente, buscar citas donde el usuario sea el cliente
      citasSnapshot = await db.collection('citas')
        .where('usuario_cliente_id', '==', userId)
        .get();
    }

    if (citasSnapshot.empty) {
      return res.json([]);
    }

    // Procesar cada cita y agregar información relevante
    const citasConInfo = await Promise.all(
      citasSnapshot.docs.map(async (doc: admin.firestore.QueryDocumentSnapshot) => {
        const cita = doc.data();
        let nombreOtraPersona = 'Desconocido';

        // Si es cliente, obtener nombre del comercio
        if (rol === 'cliente' && cita.comercio_id) {
          try {
            const comercioDoc = await db.collection('comercios').doc(cita.comercio_id).get();
            if (comercioDoc.exists) {
              nombreOtraPersona = comercioDoc.data()?.nombre || 'Salón sin nombre';
            }
          } catch (error) {
            // Ignorar error
          }
        } 
        // Si es salón, obtener nombre del cliente
        else if (rol === 'salon' && cita.usuario_cliente_id) {
          try {
            const clienteDoc = await db.collection('usuarios').doc(cita.usuario_cliente_id).get();
            if (clienteDoc.exists) {
              nombreOtraPersona = clienteDoc.data()?.nombre_completo || 'Cliente';
            }
          } catch (error) {
            // Ignorar error
          }
        }

        // Convertir fecha_hora a formato ISO
        let fechaHoraISO;
        if (cita.fecha_hora?._seconds) {
          fechaHoraISO = new Date(cita.fecha_hora._seconds * 1000).toISOString();
        } else if (typeof cita.fecha_hora === 'string') {
          fechaHoraISO = cita.fecha_hora;
        } else {
          fechaHoraISO = new Date().toISOString();
        }

        return {
          id: doc.id,
          fecha_hora: fechaHoraISO,
          nombre_otra_persona: nombreOtraPersona,
          servicio_nombre: cita.servicio_nombre || 'Servicio',
          servicio_id: cita.servicio_id,
          precio: cita.precio || 0,
          estado: cita.estado || 'pendiente',
          duracion_min: cita.duracion_min || 30,
          comercio_id: cita.comercio_id,
          cliente_id: cita.usuario_cliente_id,
        };
      })
    );

    // Ordenar por fecha
    citasConInfo.sort((a: any, b: any) => {
      return new Date(a.fecha_hora).getTime() - new Date(b.fecha_hora).getTime();
    });

    return res.json(citasConInfo);
  } catch (error: any) {
    console.error('Error al obtener citas:', error);
    return res.status(500).json({ error: 'Error al obtener citas' });
  }
};

/**
 * Verifica disponibilidad de horarios para un salón/servicio en una fecha
 * Endpoint: GET /api/citas/disponibilidad?comercioId=X&fecha=2024-01-15&servicioId=Y
 */
export const verificarDisponibilidad = async (req: Request, res: Response) => {
  try {
    const { comercioId, fecha, servicioId } = req.query;

    if (!comercioId || !fecha) {
      return res.status(400).json({ error: 'comercioId y fecha son requeridos' });
    }

    // Parsear la fecha
    const fechaObj = new Date(fecha as string);
    const inicioDia = new Date(fechaObj.getFullYear(), fechaObj.getMonth(), fechaObj.getDate(), 0, 0, 0);
    const finDia = new Date(fechaObj.getFullYear(), fechaObj.getMonth(), fechaObj.getDate(), 23, 59, 59);

    // Obtener todas las citas del día para este comercio
    const citasSnapshot = await db.collection('citas')
      .where('comercio_id', '==', comercioId)
      .get();

    // Filtrar citas del día específico
    const citasDelDia = citasSnapshot.docs
      .map((doc: admin.firestore.QueryDocumentSnapshot) => doc.data())
      .filter((cita: any) => {
        if (!cita.fecha_hora) return false;
        
        let fechaCita: Date;
        if (cita.fecha_hora._seconds) {
          fechaCita = new Date(cita.fecha_hora._seconds * 1000);
        } else if (typeof cita.fecha_hora === 'string') {
          fechaCita = new Date(cita.fecha_hora);
        } else {
          return false;
        }

        return fechaCita >= inicioDia && fechaCita <= finDia;
      });

    // Generar horarios disponibles (9:00 - 18:00 cada 30 min)
    const horariosDisponibles: { hora: string; disponible: boolean }[] = [];
    
    for (let hora = 9; hora < 18; hora++) {
      for (const minuto of [0, 30]) {
        const horaStr = `${hora.toString().padStart(2, '0')}:${minuto.toString().padStart(2, '0')}`;
        
        // Verificar si hay cita en este horario
        const ocupado = citasDelDia.some((cita: any) => {
          let fechaCita: Date;
          if (cita.fecha_hora._seconds) {
            fechaCita = new Date(cita.fecha_hora._seconds * 1000);
          } else {
            fechaCita = new Date(cita.fecha_hora);
          }

          const horaCita = fechaCita.getHours();
          const minutoCita = fechaCita.getMinutes();

          // Si se especifica servicioId, verificar solo para ese servicio
          if (servicioId) {
            return horaCita === hora && minutoCita === minuto && cita.servicio_id === servicioId;
          }

          // Verificación general
          return horaCita === hora && minutoCita === minuto;
        });

        horariosDisponibles.push({
          hora: horaStr,
          disponible: !ocupado
        });
      }
    }

    return res.json({
      fecha: fecha,
      comercioId: comercioId,
      servicioId: servicioId || null,
      horarios: horariosDisponibles
    });
  } catch (error: any) {
    console.error('Error al verificar disponibilidad:', error);
    return res.status(500).json({ error: 'Error al verificar disponibilidad' });
  }
};
