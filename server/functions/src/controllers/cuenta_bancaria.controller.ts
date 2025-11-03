import { Request, Response } from 'express';
import { db } from '../config/firebase';
import { FieldValue } from 'firebase-admin/firestore';
// Importa la función 'enmascararCuenta' desde el modelo
import { cuentaBancariaSchema, updateCuentaBancariaSchema, enmascararCuenta } from '../modelos/cuenta_bancaria.model';

export const createCuentaBancaria = async (req: Request, res: Response): Promise<void> => {
    try {
        const validation = cuentaBancariaSchema.safeParse(req.body);
        if (!validation.success) {
            res.status(400).json({ message: "Datos inválidos", issues: validation.error.issues });
            return;
        }
        const docRef = await db.collection('cuentas_bancarias').add({
            ...validation.data,
            creado_en: FieldValue.serverTimestamp(),
        });
        res.status(201).json({ message: 'Cuenta bancaria creada con éxito.', id: docRef.id });
    } catch (error: any) {
        res.status(500).json({ message: "Error interno del servidor", error: error.message });
    }
};

export const getCuentasByComercio = async (req: Request, res: Response): Promise<void> => {
    try {
        const { comercioId } = req.params;
        if (!comercioId) {
            // Corrige el retorno inválido
            res.status(400).json({ message: "Se requiere el parámetro 'comercio'." });
            return;
        }
        const snapshot = await db.collection('cuentas_bancarias').where('comercio_id', '==', comercioId).get();
        const cuentas = snapshot.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                // Ahora la función es reconocida
                numero_cuenta: enmascararCuenta(data.numero_cuenta),
            };
        });
        res.status(200).json(cuentas);
    } catch (error: any) {
        res.status(500).json({ message: "Error interno del servidor", error: error.message });
    }
};

export const updateCuentaBancaria = async (req: Request, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        const validation = updateCuentaBancariaSchema.safeParse(req.body); // Usar el esquema importado
        if (!validation.success) {
            res.status(400).json({ message: "Datos inválidos", issues: validation.error.issues });
            return;
        }
        await db.collection('cuentas_bancarias').doc(id).update(validation.data);
        res.status(200).json({ message: 'Cuenta bancaria actualizada con éxito.' });
    } catch (error: any) {
        res.status(500).json({ message: "Error interno del servidor", error: error.message });
    }
};

export const deleteCuentaBancaria = async (req: Request, res: Response): Promise<void> => {
    try {
        const { id } = req.params;
        await db.collection('cuentas_bancarias').doc(id).delete();
        res.status(200).json({ message: 'Cuenta bancaria eliminada con éxito.' });
    } catch (error: any) {
        res.status(500).json({ message: "Error interno del servidor", error: error.message });
    }
};
