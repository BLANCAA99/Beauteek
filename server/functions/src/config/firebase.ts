// functions/src/firebase.ts
import { initializeApp, getApps, applicationDefault, App } from "firebase-admin/app";
import { getFirestore, Firestore } from "firebase-admin/firestore";
import { getAuth, Auth } from "firebase-admin/auth";
import * as admin from "firebase-admin";

const DEBUG = process.env.FIREBASE_DEBUG === "true";

function dlog(...args: any[]) {
  if (DEBUG) console.log("[firebase.ts]", ...args);
}

function detectCredentialSource() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) return "ADC:file";
  if (process.env.FUNCTIONS_EMULATOR === "true") return "Emulator";
  return "ADC:runtime";
}

// TEMPORAL: Desactivar emulador de Auth para pruebas con producción
if (process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  dlog("⚠️ DESACTIVANDO Auth Emulator para usar producción");
  delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
}

let app: App;
try {
  const already = getApps();
  const credSource = detectCredentialSource();
  dlog("Inicializando Firebase Admin...");
  dlog("Credenciales:", credSource);
  dlog("FIRESTORE_EMULATOR_HOST:", process.env.FIRESTORE_EMULATOR_HOST || "(no)");
  dlog("FIREBASE_AUTH_EMULATOR_HOST:", process.env.FIREBASE_AUTH_EMULATOR_HOST || "(no)");
  dlog("GOOGLE_CLOUD_PROJECT:", process.env.GOOGLE_CLOUD_PROJECT || "(no)");
  dlog("GCLOUD_PROJECT:", process.env.GCLOUD_PROJECT || "(no)");

  if (already.length) {
    app = already[0];
    dlog("AdminApp reutilizada:", app.name);
  } else {
    // Usamos ADC (Application Default Credentials). Si estás local, apunta a tu JSON con GOOGLE_APPLICATION_CREDENTIALS
    app = initializeApp({
      // Si deseas forzar credenciales por archivo (opcional):
      // credential: process.env.GOOGLE_APPLICATION_CREDENTIALS ? cert(require(process.env.GOOGLE_APPLICATION_CREDENTIALS)) : applicationDefault(),
      credential: applicationDefault(),
    });
    dlog("AdminApp inicializada:", app.name);
  }
} catch (e: any) {
  console.error("[firebase.ts] ERROR al inicializar Firebase Admin:", e?.message || e);
  throw e;
}

let db: Firestore;
let auth: Auth;
try {
  db = getFirestore(app);
  auth = getAuth(app);
  dlog("Firestore y Auth obtenidos desde AdminApp.");
} catch (e: any) {
  console.error("[firebase.ts] ERROR al obtener Firestore/Auth:", e?.message || e);
  throw e;
}

export async function diagnosticoFirebase() {
  const result: Record<string, any> = {
    debug: DEBUG,
    projectId: app.options.projectId,
    usingEmulator: !!process.env.FIRESTORE_EMULATOR_HOST,
    authEmulator: !!process.env.FIREBASE_AUTH_EMULATOR_HOST,
  };

  try {
    const cols = await db.listCollections();
    result.rootCollectionsCount = cols.length;
    dlog("Conectividad Firestore OK. Colecciones raíz:", cols.map(c => c.id));
  } catch (e: any) {
    console.error("[firebase.ts] ERROR listCollections:", e?.message || e);
    result.firestoreListCollectionsError = e?.message || String(e);
  }

  try {
    const snap = await db.collection("_salud").doc("_ping_no_existe").get();
    result.readTestExists = snap.exists;
    dlog("Lectura de prueba OK. Doc existe:", snap.exists);
  } catch (e: any) {
    console.error("[firebase.ts] ERROR read test:", e?.message || e);
    result.firestoreReadError = e?.message || String(e);
  }

  return result;
}

// Exponer instancias compartidas
export { db, auth, admin };