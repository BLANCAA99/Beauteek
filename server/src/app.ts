import express from 'express';
import userRoutes from './routes/user.routes';
import horarioRoutes from './routes/horario.routes';
import categoriasServicioRoutes from './routes/categorias_servicio.routes';
import servicioRoutes from './routes/servicio.routes';
import pagoRoutes from './routes/pago.routes';
import favoritoRoutes from './routes/favorito.routes';
import promocionRoutes from './routes/promocion.routes';
import reseñaRoutes from './routes/reseña.routes';
import { db } from './services/firebase.service'; // Asegura que se importa para inicializar Firebase

const app = express();

app.use(express.json());
app.use('/api/users', userRoutes);
app.use('/api/horarios', horarioRoutes);
app.use('/api/categorias_servicio', categoriasServicioRoutes);
app.use('/api/servicios', servicioRoutes);
app.use('/api/pagos', pagoRoutes);
app.use('/api/favoritos', favoritoRoutes);
app.use('/api/promociones', promocionRoutes);
app.use('/api/reseñas', reseñaRoutes);


const PORT = process.env.PORT || 3000;

app.listen(PORT, async () => {
  try {
    await db.collection('test').doc('conexion').set({ ok: true, timestamp: new Date() });
    console.log('Conectado con éxito a Firebase');
  } catch (error) {
    console.error('Error al conectar a Firebase:', error.message);
  }
  console.log(`Servidor escuchando en el puerto ${PORT}`);
});