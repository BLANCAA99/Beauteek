import { Router, Request, Response } from 'express';
import { verifyToken } from '../middleware/auth.middleware';
import nodemailer from 'nodemailer';

const router = Router();

// Configurar transporte de correo (Gmail como ejemplo)
// IMPORTANTE: Debes configurar las credenciales en las variables de entorno
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER || 'gpt.krew@gmail.com',
    pass: process.env.EMAIL_PASSWORD || '' // Usar App Password de Gmail
  }
});

// Verificar configuración de correo al iniciar
console.log('📧 Configuración de correo:');
console.log('   - Usuario:', process.env.EMAIL_USER || 'NO CONFIGURADO');
console.log('   - Contraseña:', process.env.EMAIL_PASSWORD ? '✓ Configurada' : '✗ NO CONFIGURADA');

// Enviar mensaje de soporte
router.post('/enviar', verifyToken, async (req: Request, res: Response) => {
  try {
    const { nombre, email, uid, mensaje, destino } = req.body;

    if (!nombre || !email || !mensaje) {
      return res.status(400).json({ error: 'Faltan campos requeridos' });
    }

    // Enviar correo electrónico directamente (sin guardar en Firestore)
    const emailDestino = destino || process.env.EMAIL_SOPORTE || 'gpt.krew@gmail.com';
    
    console.log(`📧 Enviando mensaje de soporte de ${nombre} (${email}) a ${emailDestino}`);
    
    await transporter.sendMail({
      from: process.env.EMAIL_USER || 'gpt.krew@gmail.com',
      to: emailDestino,
      replyTo: email, // Para poder responder directamente al usuario
      subject: `[Beauteek Soporte] Mensaje de ${nombre}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(135deg, #EA963A 0%, #FF6B9D 100%); padding: 20px; border-radius: 10px 10px 0 0;">
            <h2 style="color: white; margin: 0; text-align: center;">Nuevo Mensaje de Soporte</h2>
          </div>
          
          <div style="background-color: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 10px 10px;">
            <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
              <table style="width: 100%; border-collapse: collapse;">
                <tr>
                  <td style="padding: 8px 0; color: #666; font-weight: bold;">👤 Nombre:</td>
                  <td style="padding: 8px 0; color: #333;">${nombre}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; color: #666; font-weight: bold;">📧 Email:</td>
                  <td style="padding: 8px 0; color: #333;">${email}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; color: #666; font-weight: bold;">🆔 UID:</td>
                  <td style="padding: 8px 0; color: #333;">${uid || 'No disponible'}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; color: #666; font-weight: bold;">📅 Fecha:</td>
                  <td style="padding: 8px 0; color: #333;">${new Date().toLocaleString('es-HN', { 
                    dateStyle: 'full', 
                    timeStyle: 'short' 
                  })}</td>
                </tr>
              </table>
            </div>
            
            <div style="background-color: #fff9f0; padding: 20px; border-left: 4px solid #EA963A; border-radius: 4px;">
              <h3 style="color: #EA963A; margin-top: 0;">Mensaje del usuario:</h3>
              <p style="color: #333; line-height: 1.6; white-space: pre-wrap; margin: 0;">${mensaje}</p>
            </div>
            
            <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #e0e0e0; text-align: center;">
              <p style="color: #666; font-size: 12px; margin: 5px 0;">
                Este mensaje fue enviado desde la aplicación móvil Beauteek
              </p>
              <p style="color: #666; font-size: 12px; margin: 5px 0;">
                Puedes responder directamente a este correo para contactar al usuario
              </p>
            </div>
          </div>
        </div>
      `
    });

    console.log(`✅ Correo de soporte enviado exitosamente a ${emailDestino}`);

    return res.json({
      success: true,
      mensaje: 'Tu mensaje ha sido enviado. Te contactaremos pronto.',
    });

  } catch (error: any) {
    console.error('❌ Error enviando mensaje de soporte:', error);
    console.error('Detalles:', error.message);
    return res.status(500).json({ 
      error: 'Error al enviar el mensaje',
      detalles: error.message 
    });
  }
});

export default router;
