import { Request, Response } from "express";
import { db } from "../config/firebase";

// Normalizar texto para búsqueda (quitar acentos)
const normalizarTexto = (texto: string): string => {
  return texto
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/ñ/g, 'n');
};

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

// Comparar servicios con el mismo nombre entre diferentes salones
export const compararServicios = async (req: Request, res: Response): Promise<void> => {
  console.log('[CompararServicios] ===== INICIO DEL ENDPOINT =====');
  console.log('[CompararServicios] Query params:', req.query);
  
  try {
    const { nombre, lat, lng, ordenar = 'precio' } = req.query;
    
    if (!nombre || !lat || !lng) {
      console.log('[CompararServicios] ERROR: Faltan parámetros');
      res.status(400).json({ error: "nombre, lat y lng son requeridos" });
      return;
    }
    
    const userLat = parseFloat(lat as string);
    const userLng = parseFloat(lng as string);
    const busquedaNormalizada = normalizarTexto(nombre as string);
    
    console.log(`[CompararServicios] Buscando servicios con: "${nombre}" (normalizado: "${busquedaNormalizada}")`);
    
    // Obtener todos los comercios
    const comerciosSnapshot = await db.collection('comercios').get();
    console.log(`[CompararServicios] Total comercios encontrados: ${comerciosSnapshot.size}`);
    const serviciosEncontrados: any[] = [];
    
    for (const comercioDoc of comerciosSnapshot.docs) {
      const comercio: any = { id: comercioDoc.id, ...comercioDoc.data() };
      
      try {
        // Obtener servicios del comercio
        const serviciosSnapshot = await db
          .collection('servicios')
          .where('comercio_id', '==', comercio.id)
          .get();
        
        console.log(`[CompararServicios] Comercio "${comercio.nombre}" tiene ${serviciosSnapshot.size} servicios`);
        
        for (const servicioDoc of serviciosSnapshot.docs) {
          const servicio = servicioDoc.data();
          const nombreServicioNormalizado = normalizarTexto(servicio.nombre || '');
          
          console.log(`  - Servicio: "${servicio.nombre}" (normalizado: "${nombreServicioNormalizado}")`);
          
          // Filtrar servicios que coincidan con la búsqueda
          if (nombreServicioNormalizado.includes(busquedaNormalizada)) {
            console.log(`    ✓ COINCIDE con búsqueda "${busquedaNormalizada}"`);
            // Calcular distancia
            let distancia = 0;
            try {
              // Buscar ubicación de 3 formas diferentes
              let ubicacionSnapshot = await db
                .collection('ubicaciones')
                .where('uid_usuario', '==', comercio.id)
                .where('es_principal', '==', true)
                .limit(1)
                .get();
              
              if (ubicacionSnapshot.empty) {
                ubicacionSnapshot = await db
                  .collection('ubicaciones')
                  .where('entidad_id', '==', comercio.id)
                  .where('tipo_entidad', '==', 'salon')
                  .where('es_principal', '==', true)
                  .limit(1)
                  .get();
              }
              
              if (ubicacionSnapshot.empty && comercio.uid_negocio) {
                ubicacionSnapshot = await db
                  .collection('ubicaciones')
                  .where('uid_usuario', '==', comercio.uid_negocio)
                  .where('es_principal', '==', true)
                  .limit(1)
                  .get();
              }
              
              if (!ubicacionSnapshot.empty) {
                const ubicacion = ubicacionSnapshot.docs[0].data();
                let lat, lng;
                
                if (ubicacion.geo && ubicacion.geo._latitude !== undefined && ubicacion.geo._longitude !== undefined) {
                  lat = ubicacion.geo._latitude;
                  lng = ubicacion.geo._longitude;
                } else if (ubicacion.lat !== undefined && ubicacion.lng !== undefined) {
                  lat = ubicacion.lat;
                  lng = ubicacion.lng;
                }
                
                if (lat !== undefined && lng !== undefined) {
                  distancia = calcularDistancia(userLat, userLng, lat, lng);
                }
              }
            } catch (e) {
              distancia = 999; // Si no hay ubicación, poner distancia muy alta
            }
            
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
            
            // Obtener foto del servicio
            let fotoServicio = null;
            try {
              const galeriaSnapshot = await db
                .collection('galeria_fotos')
                .where('comercio_id', '==', comercio.id)
                .where('servicio_id', '==', servicioDoc.id)
                .limit(1)
                .get();
              
              if (!galeriaSnapshot.empty) {
                fotoServicio = galeriaSnapshot.docs[0].data().foto_url;
              } else {
                // Si no hay foto del servicio, buscar cualquier foto del salón
                const galeriaGeneralSnapshot = await db
                  .collection('galeria_fotos')
                  .where('comercio_id', '==', comercio.id)
                  .limit(1)
                  .get();
                
                if (!galeriaGeneralSnapshot.empty) {
                  fotoServicio = galeriaGeneralSnapshot.docs[0].data().foto_url;
                }
              }
            } catch (e) {
              // Ignorar error
            }
            
            serviciosEncontrados.push({
              servicio: {
                id: servicioDoc.id,
                nombre: servicio.nombre || 'Servicio',
                descripcion: servicio.descripcion || '',
                precio: parseFloat((servicio.precio || 0).toString()),
                duracion: Math.max(parseInt(servicio.duracion_min || servicio.duracion || 1, 10), 1),
                comercio_id: comercio.id,
              },
              comercio: {
                id: comercio.id,
                nombre: comercio.nombre || 'Salón',
                direccion: comercio.direccion || '',
                foto_portada: comercio.foto_portada || null,
                foto_url: comercio.foto_url || null,
              },
              precio: parseFloat((servicio.precio || 0).toFixed(1)),
              duracion: Math.max(parseInt(servicio.duracion_min || servicio.duracion || 1, 10), 1),
              distancia: parseFloat((Math.round(distancia * 10) / 10).toFixed(1)),
              rating: parseFloat((Math.round(calificacion * 10) / 10).toFixed(1)),
              resenas: totalResenas || 0,
              foto_servicio: fotoServicio,
            });
          }
        }
      } catch (e) {
        // Continuar con el siguiente comercio si hay error
        continue;
      }
    }
    
    // Ordenar según el criterio solicitado (normalizar a minúsculas)
    const criterioOrdenar = (ordenar as string).toLowerCase();
    
    switch (criterioOrdenar) {
      case 'distancia':
        serviciosEncontrados.sort((a, b) => a.distancia - b.distancia);
        break;
      case 'rating':
        serviciosEncontrados.sort((a, b) => b.rating - a.rating);
        break;
      case 'precio':
      default:
        serviciosEncontrados.sort((a, b) => a.precio - b.precio);
        break;
    }
    
    console.log(`[CompararServicios] Total servicios encontrados y procesados: ${serviciosEncontrados.length}`);
    res.json(serviciosEncontrados);
  }
  catch (error: any) {
    console.error('[CompararServicios] Error:', error);
    res.status(500).json({ error: error.message });
  }
};
