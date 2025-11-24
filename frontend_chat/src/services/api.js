// API Service Layer for CarePath Frontend

// Remove trailing slashes from URLs to prevent double-slash issues
const DB_API_URL = (import.meta.env.VITE_DB_API_URL || 'http://localhost:8001').replace(/\/+$/, '');
const CHAT_API_URL = (import.meta.env.VITE_CHAT_API_URL || 'http://localhost:8000').replace(/\/+$/, '');

/**
 * Fetch all chat logs from db-api
 * @param {Object} options - Query options
 * @param {number} options.skip - Number of items to skip (default: 0)
 * @param {number} options.limit - Number of items to return (default: 10)
 * @returns {Promise<{items: Array, total: number, skip: number, limit: number}>}
 */
export async function fetchChatLogs({ skip = 0, limit = 10 } = {}) {
  const response = await fetch(
    `${DB_API_URL}/chat-logs?skip=${skip}&limit=${limit}`
  );

  if (!response.ok) {
    throw new Error(`Failed to fetch chat logs: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

/**
 * Submit a chat query to chat-api
 * @param {string} patientMrn - Patient MRN
 * @param {string} query - User's question
 * @param {string|null} llmMode - Optional LLM mode (defaults to server's DEFAULT_LLM_MODE if not provided)
 * @returns {Promise<{trace_id: string, patient_mrn: string, query: string, llm_mode: string, response: string, conversation_id: string}>}
 */
export async function submitChat(patientMrn, query, llmMode = null) {
  const body = {
    patient_mrn: patientMrn,
    query: query,
  };

  // Only include llm_mode if explicitly provided
  if (llmMode !== null) {
    body.llm_mode = llmMode;
  }

  const response = await fetch(`${CHAT_API_URL}/triage`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`Failed to submit chat: ${response.status} ${response.statusText}`);
  }

  return response.json();
}
