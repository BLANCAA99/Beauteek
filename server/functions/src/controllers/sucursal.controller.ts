import { Request, Response } from 'express';
import { db } from '../config/firebase';
import { sucursalSchema, updateSucursalSchema } from '../modelos/sucursal.model';

export const createSucursal = async (req: Request, res: Response): Promise<void> => {
    try {
        const validation = sucursalSchema.safeParse(req.body);
        if (!validation.success) {
            res.status(400).json({ message: "Datos inválidos", issues: validation.error.issues });
            return;
        }
        const docRef = await db.collection("sucursales").add(validation.data);
        res.status(201).json({ id: docRef.id, ...validation.data });
    } catch (error: any) {
        console.error("Error al crear sucursal:", error);
        res.status(500).json({ message: "Error interno del servidor", error: error.message });
    }
};

export const getSucursalesByComercio = async (req: Request, res: Response): Promise<void> => {
    try {
        const { comercioId } = req.params;
        const snapshot = await db.collection("sucursales").where("comercio_id", "==", comercioId).get();
        const sucursales = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.status(200).json(sucursales);
    } catch (error: any) {
        console.error("Error al obtener sucursales:", error);
        res.status(500).json({ message: "Error interno del servidor", error: error.message });
    }
};

export const updateSucursal = async (req: Request, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const validation = updateSucursalSchema.safeParse(req.body);
        if (!validation.success) {
            res.status(400).json({ message: "Datos inválidos", issues: validation.error.issues });
            return;
        }
        await db.collection("sucursales").doc(id).update(validation.data);
        res.status(200).json({ message: "Sucursal actualizada" });
    } catch (error: any) {
        console.error("Error al actualizar sucursal:", error);
        res.status(500).json({ message: "Error interno del servidor", error: error.message });
    }
};

export const deleteSucursal = async (req: Request, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        await db.collection("sucursales").doc(id).delete();
        res.status(200).json({ message: "Sucursal eliminada" });
    } catch (error: any) {
        console.error("Error al eliminar sucursal:", error);
        res.status(500).json({ message: "Error interno del servidor", error: error.message });
    }
};
