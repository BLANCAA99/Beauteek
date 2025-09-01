import React, { useState } from 'react';
import { View, TextInput, Text, TouchableOpacity, StyleSheet, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { auth } from '../constants/firebaseConfig';
import { signInWithEmailAndPassword, GoogleAuthProvider, signInWithCredential } from 'firebase/auth';
import * as Google from 'expo-auth-session/providers/google';

export default function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  // Configura Google Auth
  const [request, response, promptAsync] = Google.useAuthRequest({
    clientId:'82935606572-g7ngn21thomg4ur79muo35cd9cq1frus.apps.googleusercontent.com',
    iosClientId: '82935606572-5e99j2go13fj7cnmrpg98oq9picgci72.apps.googleusercontent.com',
    androidClientId:'82935606572-qm6okq5ckldct39i05riub4u9rhjggja.apps.googleusercontent.com'
  });

  React.useEffect(() => {
    if (response?.type === 'success') {
      setLoading(true);
      const { authentication } = response;
      if (authentication?.idToken) {
        const credential = GoogleAuthProvider.credential(authentication.idToken, authentication.accessToken);
        signInWithCredential(auth, credential)
          .then(() => {
            setLoading(false);
            router.replace('/(tabs)'); // Redirige a la pantalla principal
          })
          .catch(() => {
            setLoading(false);
            setError('Error al iniciar sesión con Google');
          });
      }
    }
  }, [response]);

  const handleLogin = async () => {
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
      setLoading(false);
      router.replace('/(tabs)'); // Redirige a la pantalla principal
    } catch (e) {
      setLoading(false);
      setError('Credenciales incorrectas');
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Beauteek</Text>
      <Text style={styles.subtitle}>Welcome back</Text>
      <TextInput
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        style={styles.input}
        autoCapitalize="none"
      />
      <TextInput
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        style={styles.input}
      />
      <TouchableOpacity>
        <Text style={styles.forgot}>Forgot password?</Text>
      </TouchableOpacity>
      <TouchableOpacity style={styles.button} onPress={handleLogin} disabled={loading}>
        <Text style={styles.buttonText}>Log in</Text>
      </TouchableOpacity>
      <TouchableOpacity style={styles.googleButton} onPress={() => promptAsync()} disabled={loading}>
        <Text style={styles.googleButtonText}>Iniciar con cuenta de Google</Text>
      </TouchableOpacity>
      {loading && (
        <View style={styles.loadingBox}>
          <ActivityIndicator size="small" color="#F2994A" />
          <Text style={styles.loadingText}>Iniciando sesión...</Text>
        </View>
      )}
      {error ? <Text style={{ color: 'red', marginTop: 10 }}>{error}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 24, justifyContent: 'center', backgroundColor: '#fff' },
  title: { fontSize: 22, fontWeight: 'bold', textAlign: 'center', marginBottom: 10 },
  subtitle: { fontSize: 28, fontWeight: 'bold', textAlign: 'center', marginBottom: 30 },
  input: { backgroundColor: '#f5f2ee', borderRadius: 10, padding: 16, marginBottom: 16, fontSize: 16 },
  forgot: { color: '#8d7b68', marginBottom: 20 },
  button: { backgroundColor: '#F2994A', borderRadius: 10, padding: 16, marginBottom: 16 },
  buttonText: { color: '#fff', fontWeight: 'bold', textAlign: 'center', fontSize: 16 },
  googleButton: { backgroundColor: '#fff', borderColor: '#F2994A', borderWidth: 1, borderRadius: 10, padding: 16 },
  googleButtonText: { color: '#F2994A', fontWeight: 'bold', textAlign: 'center', fontSize: 16 },
  loadingBox: {
    marginTop: 20,
    alignSelf: 'center',
    backgroundColor: '#fff8ec',
    padding: 12,
    borderRadius: 8,
    borderColor: '#F2994A',
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  loadingText: {
    color: '#F2994A',
    fontWeight: 'bold',
    fontSize: 16,
    marginLeft: 10,
  },
});