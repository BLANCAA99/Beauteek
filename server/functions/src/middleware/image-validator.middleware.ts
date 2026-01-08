import { Request, Response, NextFunction } from 'express';
import axios from 'axios';

/**
 * Middleware para validar URLs de imágenes de Cloudinary
 * Verifica:
 * - Formato de imagen (.jpg, .jpeg, .png)
 * - Tamaño de imagen (máximo 800 KB)
 */

interface ImageValidationConfig {
  maxSizeKB?: number; // Tamaño máximo en KB (por defecto 800 KB)
  allowedFormats?: string[]; // Formatos permitidos (por defecto jpg, jpeg, png)
  fieldName: string; // Nombre del campo que contiene la URL de la imagen
  required?: boolean; // Si la imagen es obligatoria
}

const DEFAULT_MAX_SIZE_KB = 800; // 800 KB
const DEFAULT_ALLOWED_FORMATS = ['.jpg', '.jpeg', '.png'];

/**
 * Valida la URL de una imagen de Cloudinary
 */
export const validateCloudinaryImage = (config: ImageValidationConfig) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const {
        maxSizeKB = DEFAULT_MAX_SIZE_KB,
        allowedFormats = DEFAULT_ALLOWED_FORMATS,
        fieldName,
        required = false,
      } = config;

      const imageUrl = req.body[fieldName];

      // Si la imagen no es requerida y no se proporcionó, continuar
      if (!imageUrl) {
        if (required) {
          return res.status(400).json({
            error: 'Validación de imagen fallida',
            detalles: `El campo ${fieldName} es obligatorio`,
          });
        }
        return next();
      }

      // Verificar que sea una URL de Cloudinary
      if (!imageUrl.includes('cloudinary.com')) {
        return res.status(400).json({
          error: 'Validación de imagen fallida',
          detalles: 'La URL debe ser de Cloudinary',
        });
      }

      // 1. Validar formato de archivo
      const urlLower = imageUrl.toLowerCase();
      const hasValidFormat = allowedFormats.some(format => 
        urlLower.includes(format) || urlLower.endsWith(format)
      );

      if (!hasValidFormat) {
        return res.status(400).json({
          error: 'Formato de imagen no permitido',
          detalles: `Solo se permiten los formatos: ${allowedFormats.join(', ')}. La imagen debe ser JPG o PNG.`,
        });
      }

      // 2. Validar tamaño de la imagen
      // Hacemos una petición HEAD para obtener el tamaño sin descargar toda la imagen
      try {
        const response = await axios.head(imageUrl, {
          timeout: 5000, // 5 segundos de timeout
        });

        const contentLength = response.headers['content-length'];
        
        if (contentLength) {
          const sizeInBytes = parseInt(contentLength, 10);
          const sizeInKB = sizeInBytes / 1024;
          const maxSizeBytes = maxSizeKB * 1024;

          console.log(`📸 [Validación] Imagen: ${sizeInKB.toFixed(2)} KB / ${maxSizeKB} KB máximo`);

          if (sizeInBytes > maxSizeBytes) {
            return res.status(400).json({
              error: 'Imagen muy grande',
              detalles: `La imagen pesa ${sizeInKB.toFixed(2)} KB. El tamaño máximo permitido es ${maxSizeKB} KB (${(maxSizeKB / 1024).toFixed(2)} MB). Por favor, reduce el tamaño de la imagen.`,
              tamanio_actual_kb: sizeInKB.toFixed(2),
              tamanio_maximo_kb: maxSizeKB,
            });
          }

          // Agregar información del tamaño validado para logs
          req.body._image_size_kb = sizeInKB.toFixed(2);
        } else {
          console.warn('⚠️ No se pudo determinar el tamaño de la imagen, pero se permite continuar');
        }
      } catch (error: any) {
        // Si falla la validación de tamaño (red, timeout, etc.), registrar error pero continuar
        console.error('❌ Error al validar tamaño de imagen:', error.message);
        console.warn('⚠️ Continuando sin validación de tamaño debido a error de red');
        // Podríamos decidir fallar aquí si queremos ser más estrictos
        // return res.status(500).json({ error: 'No se pudo validar el tamaño de la imagen' });
      }

      // Si todo está bien, continuar
      console.log(`✅ Imagen validada correctamente: ${fieldName}`);
      next();
    } catch (error: any) {
      console.error('❌ Error en middleware de validación de imagen:', error);
      return res.status(500).json({
        error: 'Error al validar la imagen',
        detalles: error.message,
      });
    }
  };
};

/**
 * Validador específico para galería de fotos
 */
export const validateGalleryImage = validateCloudinaryImage({
  fieldName: 'foto_url',
  maxSizeKB: 800,
  required: true,
});

/**
 * Validador específico para foto de perfil
 */
export const validateProfileImage = validateCloudinaryImage({
  fieldName: 'foto_url',
  maxSizeKB: 800,
  required: false,
});

/**
 * Validador específico para foto de reseña
 */
export const validateReviewImage = validateCloudinaryImage({
  fieldName: 'foto_url',
  maxSizeKB: 800,
  required: false,
});
