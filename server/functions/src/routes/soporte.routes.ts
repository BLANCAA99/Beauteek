import { Router, Request, Response } from 'express';
import { db } from '../config/firebase';
import { verifyToken } from '../middleware/auth.middleware';

const router = Router();

// Enviar mensaje de soporte
router.post('/enviar', verifyToken, async (req: Request, res: Response) => {
  try {
    const { nombre, email, uid, mensaje } = req.body;

    if (!nombre || !email || !mensaje) {
      return res.status(400).json({ error: 'Faltan campos requeridos' });
    }

    // Guardar en colección de soporte
    const soporteRef = await db.collection('soporte').add({
      nombre,
      email,
      uid: uid || null,
      mensaje,
      fecha: new Date(),
      estado: 'pendiente',
      leido: false
    });

    console.log(`✅ Mensaje de soporte guardado: ${soporteRef.id}`);

    return res.json({
      success: true,
      mensaje: 'Tu mensaje ha sido enviado. Te contactaremos pronto.',
      id: soporteRef.id
    });

  } catch (error) {
    console.error('Error enviando mensaje de soporte:', error);
    return res.status(500).json({ error: 'Error al enviar el mensaje' });
  }
});

export default router;
