// Get API URL from runtime config (injected by nginx) or fall back to relative path for dev
declare global {
  interface Window {
    APP_CONFIG?: {
      API_URL?: string;
    };
  }
}

function getApiBaseUrl(): string {
  // Check for runtime config (production - injected by nginx)
  if (window.APP_CONFIG?.API_URL) {
    return window.APP_CONFIG.API_URL;
  }
  // Fall back to relative path (works with Vite proxy in development)
  return '';
}

const API_BASE_URL = getApiBaseUrl();

export interface ChatResponse {
  response: string
}

export interface ConversationResponse {
  response: string
  conversationId: string
}

/**
 * Send a single-turn chat message to the API
 */
export async function sendMessage(message: string): Promise<string> {
  const response = await fetch(`${API_BASE_URL}/api/chat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ message }),
  })

  if (!response.ok) {
    throw new Error(`API error: ${response.status} ${response.statusText}`)
  }

  const data: ChatResponse = await response.json()
  return data.response
}

/**
 * Send a multi-turn conversation message to the API
 */
export async function sendConversationMessage(
  message: string,
  conversationId: string | null
): Promise<ConversationResponse> {
  const response = await fetch(`${API_BASE_URL}/api/chat/conversation`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ 
      message, 
      conversationId: conversationId || undefined 
    }),
  })

  if (!response.ok) {
    throw new Error(`API error: ${response.status} ${response.statusText}`)
  }

  return response.json()
}

/**
 * Check if the API is healthy
 */
export async function checkHealth(): Promise<boolean> {
  try {
    const response = await fetch(`${API_BASE_URL}/health`)
    return response.ok
  } catch {
    return false
  }
}
