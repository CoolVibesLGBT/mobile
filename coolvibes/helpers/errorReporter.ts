export type AppErrorPayload = {
  id: string;
  message: string;
  name?: string;
  stack?: string;
  source?: string;
  action?: string;
  extra?: unknown;
  fatal?: boolean;
  timestamp: number;
};

type AppErrorListener = (payload: AppErrorPayload) => void;

const listeners = new Set<AppErrorListener>();
let lastError: AppErrorPayload | null = null;
let installed = false;

const safeStringify = (value: unknown) => {
  if (value === undefined) return '';
  if (typeof value === 'string') return value;
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
};

const normalizeError = (error: unknown) => {
  if (error instanceof Error) {
    return {
      message: error.message || 'Unknown error',
      name: error.name,
      stack: error.stack,
    };
  }
  if (typeof error === 'string') {
    return { message: error };
  }
  return {
    message: safeStringify(error) || 'Unknown error',
  };
};

const createPayload = (
  error: unknown,
  context?: { source?: string; action?: string; extra?: unknown; fatal?: boolean }
): AppErrorPayload => {
  const normalized = normalizeError(error);
  return {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    message: normalized.message,
    name: normalized.name,
    stack: normalized.stack,
    source: context?.source,
    action: context?.action,
    extra: context?.extra,
    fatal: context?.fatal,
    timestamp: Date.now(),
  };
};

export const reportAppError = (
  error: unknown,
  context?: { source?: string; action?: string; extra?: unknown; fatal?: boolean }
) => {
  const payload = createPayload(error, context);
  lastError = payload;
  listeners.forEach(listener => listener(payload));
  return payload;
};

export const getLastAppError = () => lastError;

export const subscribeToAppErrors = (listener: AppErrorListener) => {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
};

export const formatErrorDetails = (payload: AppErrorPayload) => {
  const lines: string[] = [];
  lines.push(`Message: ${payload.message}`);
  if (payload.name) lines.push(`Name: ${payload.name}`);
  if (payload.source) lines.push(`Source: ${payload.source}`);
  if (payload.action) lines.push(`Action: ${payload.action}`);
  if (payload.fatal !== undefined) lines.push(`Fatal: ${payload.fatal}`);
  lines.push(`Time: ${new Date(payload.timestamp).toISOString()}`);
  if (payload.stack) lines.push(`Stack:\n${payload.stack}`);
  if (payload.extra !== undefined) {
    const extra = safeStringify(payload.extra);
    if (extra) lines.push(`Extra:\n${extra}`);
  }
  return lines.join('\n');
};

export const installGlobalErrorHandler = () => {
  if (installed) return;
  installed = true;
  const globalAny = globalThis as any;

  const errorUtils = globalAny?.ErrorUtils;
  if (errorUtils?.getGlobalHandler && errorUtils?.setGlobalHandler) {
    const defaultHandler = errorUtils.getGlobalHandler();
    errorUtils.setGlobalHandler((error: Error, isFatal?: boolean) => {
      reportAppError(error, { source: 'global', fatal: isFatal });
      if (typeof __DEV__ !== 'undefined' && __DEV__ && typeof defaultHandler === 'function') {
        defaultHandler(error, isFatal);
      }
    });
  }

  if (typeof globalAny?.addEventListener === 'function') {
    globalAny.addEventListener('unhandledrejection', (event: any) => {
      const reason = event?.reason ?? event;
      reportAppError(reason, { source: 'unhandledrejection' });
    });
  }
};
