/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/https";
process.env.FIREBASE_DEBUG = "true";

setGlobalOptions({ maxInstances: 10 });

import express from 'express';
import cors from 'cors';
import userRoutes from './routes/user.routes';
import comercioRoutes from './routes/comercio.routes'; // Asegúrate de tener este import
import horarioRoutes from './routes/horario.routes';
import categoriasServicioRoutes from './routes/categorias_servicio.routes';
import servicioRoutes from './routes/servicio.routes';
import pagoRoutes from './routes/pago.routes';
import favoritoRoutes from './routes/favorito.routes';
import promocionRoutes from './routes/promocion.routes';
import reseñaRoutes from './routes/reseña.routes';

const app = express();

app.use(cors());
app.use(express.json());

// Agregar logs para debug
app.use((req, res, next) => {
  console.log(`📨 ${req.method} ${req.path}`);
  console.log(`📨 URL completa: ${req.originalUrl}`);
  console.log(`📨 Base URL: ${req.baseUrl}`);
  next();
});

app.use('/api/users', userRoutes);
app.use('/comercios', comercioRoutes); // Sin /api porque Firebase lo quita automáticamente
console.log('✅ Rutas registradas: /api/users, /comercios');

app.use('/api/horarios', horarioRoutes);
app.use('/api/categorias_servicio', categoriasServicioRoutes);
app.use('/api/servicios', servicioRoutes);
app.use('/api/pagos', pagoRoutes);
app.use('/api/favoritos', favoritoRoutes);
app.use('/api/promociones', promocionRoutes);
app.use('/api/reseñas', reseñaRoutes);

export const api = onRequest(
  { region: "us-central1" },
  app
);