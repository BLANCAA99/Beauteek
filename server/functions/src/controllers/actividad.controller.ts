import { Request, Response } from "express";
import { db } from "../config/firebase";

interface ActividadItem {
  icono: string;
  color: string;
  accion: string;
  detalle: string;
  timestamp: string;
}

// Mapear estados de cita a iconos y colores
const mapearEstadoCita = (estado: string): { icono: string; color: string; accion: string } => {
  const mapeo: Record<string, { icono: string; color: string; accion: string }> = {
    'confirmada': { icono: 'check_circle', color: '#4CAF50', accion: 'Cita confirmada' },
    'cancelada': { icono: 'cancel', color: '#F44336', accion: 'Cita cancelada' },
    'completada': { icono: 'done_all', color: '#2196F3', accion: 'Cita completada' },
    'pendiente': { icono: 'event_available', color: '#EA963A', accion: 'Cita agendada' }
  };
  return mapeo[estado] || mapeo['pendiente'];
};

// Obtener actividad reciente según el rol del usuario (últimos 7 días)
export const getActividadReciente = async (req: Request, res: Response): Promise<void> => {
  try {
    const { uid } = req.params;
    const { rol } = req.query;
    
    if (!uid) {
      res.status(400).json({ error: "uid es requerido" });
      return;
    }
    
    const actividades: ActividadItem[] = [];
    const ahora = new Date();
    const hace7Dias = new Date(ahora);
    hace7Dias.setDate(hace7Dias.getDate() - 7);
    
    if (rol === 'salon') {
      // Obtener comercioId del salón
      const comercioSnapshot = await db
        .collection('comercios')
        .where('uid_negocio', '==', uid)
        .limit(1)
        .get();
        
      if (comercioSnapshot.empty) {
        res.json([]);
        return;
      }
      
      const comercioId = comercioSnapshot.docs[0].id;
      
      // 1. Cargar citas pendientes de los últimos 7 días
      const citasSnapshot = await db
        .collection('citas')
        .where('comercio_id', '==', comercioId)
        .where('estado', '==', 'pendiente')
        .where('fecha_hora', '>=', hace7Dias)
        .orderBy('fecha_hora', 'desc')
        .limit(20)
        .get();
        
      citasSnapshot.forEach(doc => {
        const data = doc.data();
        const fechaHora = data.fecha_hora?.toDate ? data.fecha_hora.toDate() : new Date(data.fecha_hora);
        
        actividades.push({
          icono: 'event_available',
          color: '#EA963A',
          accion: 'Nueva cita agendada',
          detalle: `Cliente: ${data.usuario_nombre || 'Cliente'}`,
          timestamp: fechaHora.toISOString()
        });
      });
      
      // 2. Cargar promociones creadas en los últimos 7 días
      const promocionesSnapshot = await db
        .collection('promociones')
        .where('comercio_id', '==', comercioId)
        .where('fecha_creacion', '>=', hace7Dias)
        .orderBy('fecha_creacion', 'desc')
        .limit(15)
        .get();
        
      promocionesSnapshot.forEach(doc => {
        const data = doc.data();
        const fechaCreacion = data.fecha_creacion?.toDate ? data.fecha_creacion.toDate() : new Date(data.fecha_creacion);
        
        actividades.push({
          icono: 'local_offer',
          color: '#FF9800',
          accion: 'Nueva promoción creada',
          detalle: `${data.servicio_nombre || 'Servicio'} - ${data.valor}% descuento`,
          timestamp: fechaCreacion.toISOString()
        });
      });
      
      // 3. Cargar fotos agregadas a la galería en los últimos 7 días
      const fotosSnapshot = await db
        .collection('galeria_fotos')
        .where('comercio_id', '==', comercioId)
        .where('created_at', '>=', hace7Dias)
        .orderBy('created_at', 'desc')
        .limit(15)
        .get();
        
      fotosSnapshot.forEach(doc => {
        const data = doc.data();
        const fechaCreacion = data.created_at?.toDate ? data.created_at.toDate() : new Date(data.created_at);
        
        actividades.push({
          icono: 'add_photo_alternate',
          color: '#9C27B0',
          accion: 'Nueva foto agregada',
          detalle: 'Foto agregada a la galería del salón',
          timestamp: fechaCreacion.toISOString()
        });
      });
    } else {
      // CLIENTE: Cargar citas, reseñas y favoritos de los últimos 7 días
      
      // 1. Citas del cliente
      const citasSnapshot = await db
        .collection('citas')
        .where('usuario_id', '==', uid)
        .where('fecha_hora', '>=', hace7Dias)
        .orderBy('fecha_hora', 'desc')
        .limit(50)
        .get();
        
      citasSnapshot.forEach(doc => {
        const data = doc.data();
        const estado = data.estado || 'pendiente';
        const estadoInfo = mapearEstadoCita(estado);
        const fechaHora = data.fecha_hora?.toDate ? data.fecha_hora.toDate() : new Date(data.fecha_hora);
        
        actividades.push({
          icono: estadoInfo.icono,
          color: estadoInfo.color,
          accion: estadoInfo.accion,
          detalle: `Con ${data.comercio_nombre || 'Salón'}`,
          timestamp: fechaHora.toISOString()
        });
      });
      
      // 2. Reseñas del cliente
      const resenasSnapshot = await db
        .collection('resenas')
        .where('usuario_id', '==', uid)
        .where('fecha_creacion', '>=', hace7Dias)
        .orderBy('fecha_creacion', 'desc')
        .limit(20)
        .get();
        
      resenasSnapshot.forEach(doc => {
        const data = doc.data();
        const fechaCreacion = data.fecha_creacion?.toDate ? data.fecha_creacion.toDate() : new Date(data.fecha_creacion);
        
        actividades.push({
          icono: 'rate_review',
          color: '#FFC107',
          accion: 'Reseña enviada',
          detalle: `${data.calificacion || 0} ⭐ - ${data.comercio_nombre || 'Salón'}`,
          timestamp: fechaCreacion.toISOString()
        });
      });
      
      // 3. Favoritos agregados
      const favoritosSnapshot = await db
        .collection('favoritos')
        .where('cliente_id', '==', uid)
        .where('fecha_creacion', '>=', hace7Dias)
        .orderBy('fecha_creacion', 'desc')
        .limit(20)
        .get();
        
      for (const doc of favoritosSnapshot.docs) {
        const data = doc.data();
        const fechaCreacion = data.fecha_creacion?.toDate ? data.fecha_creacion.toDate() : new Date(data.fecha_creacion);
        
        // Obtener nombre del comercio
        let comercioNombre = 'Salón';
        try {
          const comercioDoc = await db.collection('comercios').doc(data.salon_id).get();
          if (comercioDoc.exists) {
            comercioNombre = comercioDoc.data()?.nombre || 'Salón';
          }
        } catch (e) {
          // Ignorar error
        }
        
        actividades.push({
          icono: 'favorite',
          color: '#E91E63',
          accion: 'Salón agregado a favoritos',
          detalle: comercioNombre,
          timestamp: fechaCreacion.toISOString()
        });
      }
    }
    
    // Ordenar por fecha descendente (más reciente primero)
    actividades.sort((a, b) => {
      const fechaA = new Date(a.timestamp).getTime();
      const fechaB = new Date(b.timestamp).getTime();
      return fechaB - fechaA;
    });
    
    res.json(actividades);
  }
  catch (error: any) {
    console.error('Error obteniendo actividad reciente:', error);
    res.status(500).json({ error: error.message });
  }
};
