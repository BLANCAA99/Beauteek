import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: 'AIzaSyD_0q9FGmNkNB95PqjIVplvAcq8UDs8H1U',
  authDomain: 'beauteek-b595e.firebaseapp.com',
  projectId: 'beauteek-b595e',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);