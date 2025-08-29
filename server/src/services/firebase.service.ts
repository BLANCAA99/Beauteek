const admin = require('firebase-admin');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config();

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
const databaseURL = process.env.FIREBASE_DATABASE_URL;

if (!serviceAccountPath || !databaseURL) {
  throw new Error('Faltan variables de entorno de Firebase');
}

const serviceAccount = require(path.resolve(serviceAccountPath));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL,
  });
}

export const db = admin.firestore();
export const auth = admin.auth();