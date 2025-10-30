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

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
import express from 'express';
import cors from 'cors';
import userRoutes from './routes/user.routes';
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
app.use('/api/users', userRoutes);
app.use('/api/horarios', horarioRoutes);
app.use('/api/categorias_servicio', categoriasServicioRoutes);
app.use('/api/servicios', servicioRoutes);
app.use('/api/pagos', pagoRoutes);
app.use('/api/favoritos', favoritoRoutes);
app.use('/api/promociones', promocionRoutes);
app.use('/api/reseñas', reseñaRoutes);


export const api = onRequest(
  { region: "us-central1" }, // ajusta región si quieres
  app
);