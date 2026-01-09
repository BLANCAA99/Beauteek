import { Request, Response } from "express";
import { db } from "../config/firebase";

// Calcular distancia entre dos puntos GPS (fórmula Haversine)
const calcularDistancia = (lat1: number, lng1: number, lat2: number, lng2: number): number => {
  const R = 6371; // Radio de la Tierra en km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distancia en km
};

// Buscar salones por país del usuario
export const buscarSalonesPorPais = async (req: Request, res: Response): Promise<void> => {
  try {
    const { userId, lat, lng } = req.query;
    
    if (!userId) {
      res.status(400).json({ error: "userId es requerido" });
      return;
    }
    
    // Obtener ubicación principal del usuario para saber su país
    const ubicacionUsuarioSnapshot = await db
      .collection('ubicaciones')
      .where('uid_usuario', '==', userId)
      .where('tipo_entidad', '==', 'cliente')
      .where('es_principal', '==', true)
      .limit(1)
      .get();
    
    if (ubicacionUsuarioSnapshot.empty) {
      res.status(404).json({ error: "Usuario no tiene ubicación configurada" });
      return;
    }
    
    const ubicacionUsuario = ubicacionUsuarioSnapshot.docs[0].data();
    const paisUsuario = ubicacionUsuario.pais;
    const userLat = lat ? parseFloat(lat as string) : ubicacionUsuario.geo?._latitude || ubicacionUsuario.lat;
    const userLng = lng ? parseFloat(lng as string) : ubicacionUsuario.geo?._longitude || ubicacionUsuario.lng;
    
    if (!paisUsuario) {
      res.status(400).json({ error: "Usuario no tiene país configurado" });
      return;
    }
    
    console.log(`Buscando salones en país: ${paisUsuario}`);
    
    // Buscar ubicaciones de salones en el mismo país
    const ubicacionesSnapshot = await db
      .collection('ubicaciones')
      .where('pais', '==', paisUsuario)
      .where('tipo_entidad', '==', 'salon')
      .get();
    
    console.log(`Ubicaciones encontradas en ${paisUsuario}: ${ubicacionesSnapshot.size}`);
    
    const salonesEncontrados: any[] = [];
    const salonesYaProcesados = new Set<string>(); // Para evitar duplicados
    
    // Ordenar ubicaciones: principales primero
    const ubicacionesOrdenadas = ubicacionesSnapshot.docs.sort((a, b) => {
      const esA = a.data().es_principal ? 1 : 0;
      const esB = b.data().es_principal ? 1 : 0;
      return esB - esA; // Principales primero
    });
    
    for (const ubicacionDoc of ubicacionesOrdenadas) {
      const ubicacion = ubicacionDoc.data();
      
      // Obtener comercio ID - intentar por uid_usuario primero, luego entidad_id
      let comercioId = ubicacion.uid_usuario || ubicacion.entidad_id;
      
      if (!comercioId) continue;
      
      // Si ya procesamos este salón, saltar (evitar duplicados)
      if (salonesYaProcesados.has(comercioId)) continue;
      
      // Extraer coordenadas
      let comercioLat: number | undefined;
      let comercioLng: number | undefined;
      
      if (ubicacion.geo && ubicacion.geo._latitude !== undefined && ubicacion.geo._longitude !== undefined) {
        comercioLat = ubicacion.geo._latitude;
        comercioLng = ubicacion.geo._longitude;
      } else if (ubicacion.lat !== undefined && ubicacion.lng !== undefined) {
        comercioLat = ubicacion.lat;
        comercioLng = ubicacion.lng;
      }
      
      if (comercioLat === undefined || comercioLng === undefined) continue;
      
      // Calcular distancia
      const distancia = calcularDistancia(userLat, userLng, comercioLat, comercioLng);
      
      try {
        const comercioDoc = await db.collection('comercios').doc(comercioId).get();
        
        if (!comercioDoc.exists) continue;
        
        const comercio: any = { id: comercioDoc.id, ...comercioDoc.data() };
        
        // Solo comercios activos o paso3_completado
        const estadosPermitidos = ['activo', 'paso3_completado'];
        if (!estadosPermitidos.includes(comercio.estado)) continue;
        
        // Marcar como procesado para evitar duplicados
        salonesYaProcesados.add(comercioId);
        
        // Obtener calificación promedio
        let calificacion = 0;
        let totalResenas = 0;
        try {
          const resenasSnapshot = await db
            .collection('resenas')
            .where('comercio_id', '==', comercio.id)
            .get();
          
          if (!resenasSnapshot.empty) {
            let sumaCalificaciones = 0;
            resenasSnapshot.forEach(resenaDoc => {
              const resena = resenaDoc.data();
              if (resena.calificacion) {
                sumaCalificaciones += parseFloat(resena.calificacion);
                totalResenas++;
              }
            });
            calificacion = totalResenas > 0 ? sumaCalificaciones / totalResenas : 0;
          }
        } catch (e) {
          // Ignorar error
        }
        
        // Obtener foto del propietario
        let fotoUrl = null;
        try {
          if (comercio.uid_negocio) {
            const usuarioSnapshot = await db
              .collection('usuarios')
              .where('uid', '==', comercio.uid_negocio)
              .limit(1)
              .get();
            
            if (!usuarioSnapshot.empty) {
              fotoUrl = usuarioSnapshot.docs[0].data().foto_url;
            }
          }
        } catch (e) {
          // Ignorar error
        }
        
        // Obtener servicios del salón
        const serviciosSnapshot = await db
          .collection('servicios')
          .where('comercio_id', '==', comercio.id)
          .limit(3)
          .get();
        
        const servicios = serviciosSnapshot.docs.map(doc => ({
          id: doc.id,
          nombre: doc.data().nombre || '',
          precio: parseFloat(doc.data().precio || 0),
        }));
        
        salonesEncontrados.push({
          id: comercio.id,
          nombre: comercio.nombre || 'Salón',
          direccion: comercio.direccion || '',
          ubicacion: {
            lat: comercioLat,
            lng: comercioLng,
          },
          distancia: parseFloat((Math.round(distancia * 10) / 10).toFixed(1)),
          calificacion: parseFloat((Math.round(calificacion * 10) / 10).toFixed(1)),
          resenas: totalResenas,
          foto_url: fotoUrl,
          servicios: servicios,
        });
      } catch (e) {
        // Continuar con el siguiente
        continue;
      }
    }
    
    // Ordenar por distancia (más cercano primero)
    salonesEncontrados.sort((a, b) => a.distancia - b.distancia);
    
    console.log(`Salones encontrados en ${paisUsuario}: ${salonesEncontrados.length}`);
    
    res.json(salonesEncontrados);
  } catch (error: any) {
    console.error('Error buscando salones por país:', error);
    res.status(500).json({ error: error.message });
  }
};
