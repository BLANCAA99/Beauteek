import { Request, Response, NextFunction } from "express";
import { admin } from "../config/firebase";

export const verifyToken = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      console.log("[Auth] Token no proporcionado");
      res.status(401).json({ error: "Token no proporcionado" });
      return;
    }

    const token = authHeader.split("Bearer ")[1];
    console.log("[Auth] Verificando token...");
    
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    console.log(`[Auth] Token válido para usuario: ${decodedToken.uid}`);
    
    // Agregar información del usuario a la request
    (req as any).user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      role: decodedToken.role,
    };

    next();
  } catch (error: any) {
    console.error("[Auth] Error al verificar token:", error.message);
    res.status(401).json({ error: "Token inválido o expirado" });
  }
};
