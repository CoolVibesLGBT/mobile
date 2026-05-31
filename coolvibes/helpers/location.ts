import { Alert, Linking } from 'react-native';
import * as Location from 'expo-location';

export type AppCoordinates = {
  latitude: number;
  longitude: number;
};

type LocationAccessOptions = {
  blockedTitle?: string;
  blockedMessage?: string;
  unavailableTitle?: string;
  unavailableMessage?: string;
  promptOpenSettings?: boolean;
  alertOnUnavailable?: boolean;
};

const DEFAULT_BLOCKED_TITLE = 'Location access needed';
const DEFAULT_BLOCKED_MESSAGE =
  'Allow location access to continue with this feature.';
const DEFAULT_UNAVAILABLE_TITLE = 'Location unavailable';
const DEFAULT_UNAVAILABLE_MESSAGE =
  'We could not get your location right now. Please try again.';

const openLocationSettingsAlert = (
  title: string,
  message: string,
) => {
  Alert.alert(title, message, [
    { text: 'Cancel', style: 'cancel' },
    {
      text: 'Open Settings',
      onPress: () => {
        void Linking.openSettings().catch(() => {});
      },
    },
  ]);
};

export async function ensureForegroundLocationPermission(
  options: LocationAccessOptions = {},
): Promise<boolean> {
  const {
    blockedTitle = DEFAULT_BLOCKED_TITLE,
    blockedMessage = DEFAULT_BLOCKED_MESSAGE,
    promptOpenSettings = true,
  } = options;

  try {
    const permission = await Location.getForegroundPermissionsAsync();
    if (permission.granted) return true;

    if (permission.canAskAgain) {
      const requestedPermission =
        await Location.requestForegroundPermissionsAsync();
      if (requestedPermission.granted) return true;

      if (!requestedPermission.canAskAgain && promptOpenSettings) {
        openLocationSettingsAlert(blockedTitle, blockedMessage);
      }
      return false;
    }

    if (promptOpenSettings) {
      openLocationSettingsAlert(blockedTitle, blockedMessage);
    }
    return false;
  } catch {
    return false;
  }
}

export async function getCurrentOrLastKnownCoordinates(
  options: LocationAccessOptions = {},
): Promise<AppCoordinates | null> {
  const {
    unavailableTitle = DEFAULT_UNAVAILABLE_TITLE,
    unavailableMessage = DEFAULT_UNAVAILABLE_MESSAGE,
    alertOnUnavailable = false,
  } = options;

  const hasPermission = await ensureForegroundLocationPermission(options);
  if (!hasPermission) return null;

  try {
    const location = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.Balanced,
    });

    return {
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
    };
  } catch {
    try {
      const lastKnown = await Location.getLastKnownPositionAsync({});
      if (lastKnown?.coords) {
        return {
          latitude: lastKnown.coords.latitude,
          longitude: lastKnown.coords.longitude,
        };
      }
    } catch {
      // Ignore and fall through to the unavailable alert.
    }
  }

  if (alertOnUnavailable) {
    Alert.alert(unavailableTitle, unavailableMessage);
  }

  return null;
}
