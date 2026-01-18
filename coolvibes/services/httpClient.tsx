import axios from 'axios';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

import { serviceURL, defaultServiceServerId, TEST_ACCESS_TOKEN } from '../config';

const httpClient = axios.create({
  baseURL: serviceURL[defaultServiceServerId],
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