// Chat Component
import { submitChat } from '../services/api';

export default function Chat({ chatState, onStateChange }) {
  const { query, patientMrn, response, isLoading, error } = chatState;

  async function handleSubmit(e) {
    e.preventDefault();
    if (!query.trim() || !patientMrn.trim()) return;

    onStateChange({ isLoading: true, error: null });

    try {
      const result = await submitChat(patientMrn, query);
      onStateChange({ response: result, isLoading: false });
    } catch (err) {
      onStateChange({ error: err.message, isLoading: false });
    }
  }

  function handleNewChat() {
    onStateChange({
      query: '',
      patientMrn: 'P000123',
      response: null,
      isLoading: false,
      error: null,
    });
  }

  return (
    <div className="space-y-6">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Patient MRN Input */}
        <div>
          <label htmlFor="patientMrn" className="block text-sm font-medium text-gray-700 mb-1">
            Patient MRN
          </label>
          <input
            type="text"
            id="patientMrn"
            value={patientMrn}
            onChange={(e) => onStateChange({ patientMrn: e.target.value })}
            placeholder="e.g., P000123"
            className="w-full max-w-xs px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            disabled={isLoading}
          />
          <p className="mt-1 text-xs text-gray-500">Demo MRNs: P000001-P000050</p>
        </div>

        {/* Query Input */}
        <div>
          <label htmlFor="query" className="block text-sm font-medium text-gray-700 mb-1">
            Your Question
          </label>
          <textarea
            id="query"
            value={query}
            onChange={(e) => onStateChange({ query: e.target.value })}
            placeholder="Ask a question about your health records..."
            rows={4}
            className="w-full p-4 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none resize-none"
            disabled={isLoading}
          />
        </div>

        {/* Submit Button */}
        <div className="flex items-center space-x-4">
          <button
            type="submit"
            disabled={isLoading || !query.trim() || !patientMrn.trim()}
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
          >
            {isLoading && (
              <span className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></span>
            )}
            {isLoading ? 'Submitting...' : 'Submit'}
          </button>

          {response && (
            <button
              type="button"
              onClick={handleNewChat}
              className="border border-gray-300 hover:bg-gray-50 text-gray-700 px-6 py-2 rounded-lg font-medium transition-colors"
            >
              New Chat
            </button>
          )}
        </div>
      </form>

      {/* Error Display */}
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg">
          <strong>Error:</strong> {error}
        </div>
      )}

      {/* Response Display */}
      {response && (
        <div className="bg-gray-50 p-6 rounded-lg border border-gray-200">
          <h3 className="text-sm font-medium text-gray-500 mb-2">Response</h3>
          <div className="prose prose-sm max-w-none">
            <p className="text-gray-900 whitespace-pre-wrap">{response.response}</p>
          </div>

          <div className="mt-4 pt-4 border-t border-gray-200 text-xs text-gray-500 space-y-1">
            <p><strong>Conversation ID:</strong> {response.conversation_id}</p>
            <p><strong>Trace ID:</strong> {response.trace_id}</p>
            <p><strong>LLM Mode:</strong> {response.llm_mode}</p>
          </div>
        </div>
      )}
    </div>
  );
}
