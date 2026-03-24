import axios from 'axios';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';


const httpClient = axios.create({
  baseURL: "http://192.168.0.14:3001",//serviceURL[defaultServiceServerId],
  timeout: 10000,
  headers: {},
});

httpClient.interceptors.request.use(
  async (config) => {
    let token: string | null = null;

    if (Platform.OS === 'web') {
      // Web fallback
      token = localStorage.getItem('authToken');
    } else {
      // Mobile (iOS / Android)
      token = await SecureStore.getItemAsync('authToken');
    }

    const auth = token;

    if (auth && config.headers) {
      config.headers.Authorization = auth;
    }


    return config;
  },
  (error) => Promise.reject(error)
);

export default httpClient;