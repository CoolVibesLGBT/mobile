import { configureStore } from '@reduxjs/toolkit';
import chatReducer from './slice/chat';
import systemReducer from './slice/system';
import authReducer from './slice/auth';
import placesReducer from './slice/places';
import nearbyUsersReducer from './slice/nearbyUsers';
import postUploadsReducer from './slice/postUploads';
import featureFlagsReducer from './slice/featureFlags';

export const store = configureStore({
  reducer: {
    auth: authReducer,
    chat: chatReducer,
    system: systemReducer,
    nearbyPlaces: placesReducer,
    nearbyUsers: nearbyUsersReducer,
    postUploads: postUploadsReducer,
    featureFlags: featureFlagsReducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        warnAfter: 128, // Increase threshold for large system stats
      },
    }),
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
