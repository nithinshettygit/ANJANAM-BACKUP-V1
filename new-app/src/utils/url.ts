import { API_CONFIG } from '@/constants';

/**
 * Gets the configured backend base URL.
 * This should be the single source of truth for the backend origin.
 */
export const getBackendUrl = (): string => {
  // Remove trailing slash if present for consistency
  return API_CONFIG.SALEOR_URL.replace(/\/graphql\/?$/, '').replace(/\/+$/, '');
};

/**
 * Replaces 'localhost' or '127.0.0.1' in a URL with the configured backend host.
 * This is useful for images returning from the backend with localhost URLs.
 * 
 * @param url The URL string to fix (e.g., "http://localhost:8000/media/...")
 * @returns The fixed URL (e.g., "http://192.168.1.3:8000/media/...")
 */
export const fixImageUrl = (url: string | null | undefined): string => {
  if (!url) return '';

  // If it's already a remote URL (not localhost), strictly speaking we might leave it,
  // but for development we often want to force the configured IP.

  const backendUrl = getBackendUrl();
  const backendHost = backendUrl.replace(/^https?:\/\//, ''); // e.g. "192.168.1.3:8000" or "example.com"

  // Replace localhost:8000
  let fixed = url.replace('localhost:8000', backendHost);

  // Replace 127.0.0.1:8000
  fixed = fixed.replace('127.0.0.1:8000', backendHost);

  // Also replace any old hardcoded IPs if they exist in the incoming string (legacy safety)
  fixed = fixed.replace('192.168.1.3:8000', backendHost);

  return fixed;
};
