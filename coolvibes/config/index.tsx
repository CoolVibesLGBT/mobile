export const applicationName = "coolvibes";

export const RECAPTCHA_SITE_KEY = "6LecaQIsAAAAAOptodMnAZCOiKSVysrvKnmsXDix"; // Test key for development
export const YOUTUBE_API_KEY = "AIzaSyDVaUFhS8lcvNWZCsupEWC-m6CH1RGrMIU";
export const TENOR_API_KEY = "AIzaSyDVaUFhS8lcvNWZCsupEWC-m6CH1RGrMIU";
export const GOOGLE_PLACES_KEY = "AIzaSyDVaUFhS8lcvNWZCsupEWC-m6CH1RGrMIU"
export const TEST_ACCESS_TOKEN = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiNWU0ZjU3OWEtNjVlOC00NDIyLThkMWYtZWM5ZDllOWQwYTQ5IiwicHVibGljX2lkIjoyMDEwOTIyMzM4NDU5MDYyMjcyLCJleHAiOjE4MDI0MzMzMDUsImlzcyI6IkNPT0xWSUJFUyIsIm5iZiI6MTc2ODMwNTMwNSwic3ViIjoiQVVUSCJ9.yHrpXOTo1r-NDsETDGDGQPYc8CkMGO2kx8pVSOV_EjM"
// Manuel olarak ortamı belirt
const isDev = false; 

// Remote debug flag (gerekiyorsa)
const remoteDebug = false;

// Domain bazlı URL yapılarını bir nesnede tutuyoruz (istersen ileride daha dinamik yapabilirsin)
const domainToServiceURL: Record<string, [string, string]> = {
  'coolvibes.lgbt': ['https://api.coolvibes.lgbt', 'https://api.coolvibes.lgbt'],
  'coolvibes.io': ['https://api.coolvibes.io', 'https://api.coolvibes.io'],
  'coolvibes.app': ['https://api.coolvibes.app', 'https://api.coolvibes.app'],
};

const domainToSocketURL: Record<string, [string, string]> = {
  'coolvibes.lgbt': ['wss://socket.coolvibes.lgbt', 'wss://socket2.coolvibes.lgbt'],
  'coolvibes.io': ['wss://socket.coolvibes.io', 'wss://socket2.coolvibes.io'],
  'coolvibes.app': ['wss://socket.coolvibes.app', 'wss://socket2.coolvibes.app'],
};

// React Native’de domain bilgisini dışarıdan almak zor, varsayılanı production olarak ayarla
// İstersen bunu manuel olarak değiştirilebilir yapabilirsin (örneğin: AsyncStorage veya env ile)
const currentDomain = 'coolvibes.app';

// Default URL'ler remoteDebug durumuna göre
const defaultServiceURL: [string, string] = remoteDebug
  ? ['https://api.coolvibes.app', 'https://api.coolvibes.app']
  : ['http://localhost:3001', 'http://localhost:3000'];

const defaultSocketURL: [string, string] = remoteDebug
  ? ['wss://socket.coolvibes.app', 'wss://socket2.coolvibes.app']
  : ['ws://localhost:3002', 'ws://localhost:3003'];

export const defaultServiceServerId = 0;
export const serviceURL = isDev
  ? defaultServiceURL
  : domainToServiceURL[currentDomain] || defaultServiceURL;

export const defaultSocketServerId = 0;
export const socketURL = isDev
  ? defaultSocketURL
  : domainToSocketURL[currentDomain] || defaultSocketURL;

export const MAX_MESSAGE_LENGTH = 2000;