import * as dotenv from 'dotenv';
dotenv.config();

import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/https";

process.env.FIREBASE_DEBUG = "true";
setGlobalOptions({ maxInstances: 10 });

import express from 'express';
import cors from 'cors';

import userRoutes from './routes/user.routes';
import comercioRoutes from './routes/comercio.routes';
import horarioRoutes from './routes/horario.routes';
import categoriasServicioRoutes from './routes/categorias_servicio.routes';
import servicioRoutes from './routes/servicio.routes';
import pagoRoutes from './routes/pago.routes';
import favoritoRoutes from './routes/favorito.routes';
import promocionRoutes from './routes/promocion.routes';
import reseñaRoutes from './routes/reseña.routes';
import tarjetaRoutes from './routes/tarjeta.routes';
import citaRoutes from './routes/cita.routes';
import galeriaFotoRoutes from './routes/galeria_foto.routes';
import ubicacionRoutes from './routes/ubicacion.routes';
import suscripcionRoutes from './routes/suscripcion.routes';
import reporteRoutes from './routes/reporte.routes';
import soporteRoutes from './routes/soporte.routes';
import chatbotRoutes from './routes/chatbot.routes';
import metodoPagoSalonRoutes from './routes/metodo_pago_salon.routes';
import configuracionSalonRoutes from './routes/configuracion_salon.routes';
import actividadRoutes from './routes/actividad.routes';
import estadisticasRoutes from './routes/estadisticas.routes';
import compararServiciosRoutes from './routes/comparar_servicios.routes';
import buscarSalonesPaisRoutes from './routes/buscar_salones_pais.routes';
import citasRoutesNew from './routes/citas.routes';
// Funciones programadas
export { sendDailyAppointmentReminders } from './scheduled/appointment-reminders';

const app = express();

app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  console.log(`${req.method} ${req.path}`);
  console.log(`URL completa: ${req.originalUrl}`);
  console.log(`Base URL: ${req.baseUrl}`);
  next();
});

// Rutas de la API - Endpoints disponibles para el cliente
app.use('/api/users', userRoutes);
app.use('/comercios', comercioRoutes);
app.use('/categorias_servicio', categoriasServicioRoutes);
app.use('/api/tarjetas', tarjetaRoutes);
app.use('/api/horarios', horarioRoutes);
app.use('/api/servicios/comparar', compararServiciosRoutes); // ANTES de /api/servicios
app.use('/api/servicios', servicioRoutes);
app.use('/api/pagos', pagoRoutes);
app.use('/api/favoritos', favoritoRoutes);
app.use('/api/promociones', promocionRoutes);
app.use('/api/resenas', reseñaRoutes);
app.use('/citas', citaRoutes);
app.use('/api/galeria-fotos', galeriaFotoRoutes);
app.use('/api/ubicaciones', ubicacionRoutes);
app.use('/api/suscripciones', suscripcionRoutes);
app.use('/api/reportes', reporteRoutes);
app.use('/api/soporte', soporteRoutes);
app.use('/api/chatbot', chatbotRoutes);
app.use('/api/metodos-pago-salon', metodoPagoSalonRoutes);
app.use('/api/configuracion-salon', configuracionSalonRoutes);
app.use('/api/actividad', actividadRoutes);
app.use('/api/estadisticas', estadisticasRoutes);
app.use('/api/salones', buscarSalonesPaisRoutes);
app.use('/api/citas', citasRoutesNew);

export const api = onRequest({ region: "us-central1" }, app);