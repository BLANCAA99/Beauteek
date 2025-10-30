"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.auth = exports.db = void 0;
var admin = require('firebase-admin');
var dotenv = require('dotenv');
var path = require('path');
dotenv.config();
var serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
var databaseURL = process.env.FIREBASE_DATABASE_URL;
if (!serviceAccountPath || !databaseURL) {
    throw new Error('Faltan variables de entorno de Firebase');
}
var serviceAccount = require(path.resolve(serviceAccountPath));
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: databaseURL,
    });
}
exports.db = admin.firestore();
exports.auth = admin.auth();
