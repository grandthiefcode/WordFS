import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { discoverServer } from './ServerDiscovery';

const DEFAULT_API_BASE_URL: string = 'http://10.0.2.2:8080';
const PREFERENCES_NAME: string = 'api_config';
const STORAGE_API_BASE_URL: string = 'apiBaseUrl';
const STORAGE_AUTO_DISCOVER: string = 'autoDiscover';
let apiBaseUrl: string = DEFAULT_API_BASE_URL;
let autoDiscover: boolean = true;
let apiPreferences: preferences.Preferences | null = null;

export function initApiConfig(context: Context): void {
  try {
    apiPreferences = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    const storedUrl: preferences.ValueType = apiPreferences.getSync(STORAGE_API_BASE_URL, DEFAULT_API_BASE_URL);
    const storedAuto: preferences.ValueType = apiPreferences.getSync(STORAGE_AUTO_DISCOVER, true);
    if (typeof storedAuto === 'boolean') {
      autoDiscover = storedAuto;
    }
    if (autoDiscover) {
      discoverServer().then((url: string) => {
        apiBaseUrl = url;
        if (apiPreferences !== null) {
          apiPreferences.putSync(STORAGE_API_BASE_URL, url);
          apiPreferences.flushSync();
        }
        console.info('[ApiConfig] Auto-discovered server: ' + url);
      });
    } else if (typeof storedUrl === 'string' && storedUrl.trim().length > 0) {
      apiBaseUrl = normalizeApiBaseUrl(storedUrl);
    }
  } catch (error) {
    const err = error as BusinessError<number>;
    console.error('init api config failed: ' + err.message);
  }
}

function normalizeApiBaseUrl(value: string): string {
  let normalized: string = value.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

export function getApiBaseUrl(): string {
  return apiBaseUrl;
}

export function isAutoDiscover(): boolean {
  return autoDiscover;
}

export function setAutoDiscover(value: boolean): void {
  autoDiscover = value;
  if (apiPreferences === null) {
    return;
  }
  try {
    apiPreferences.putSync(STORAGE_AUTO_DISCOVER, value);
    apiPreferences.flushSync();
  } catch (error) {
    const err = error as BusinessError<number>;
    console.error('save auto discover config failed: ' + err.message);
  }
}

export function setApiBaseUrl(value: string): void {
  apiBaseUrl = normalizeApiBaseUrl(value);
  if (apiPreferences === null) {
    return;
  }
  try {
    apiPreferences.putSync(STORAGE_API_BASE_URL, apiBaseUrl);
    apiPreferences.flushSync();
  } catch (error) {
    const err = error as BusinessError<number>;
    console.error('save api config failed: ' + err.message);
  }
}
