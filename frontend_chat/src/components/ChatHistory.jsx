// Chat History Component
import { useState, useEffect } from 'react';
import { fetchChatLogs } from '../services/api';

export default function ChatHistory() {
  const [chatLogs, setChatLogs] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [pagination, setPagination] = useState({ skip: 0, limit: 10, total: 0 });

  useEffect(() => {
    loadChatLogs();
  }, [pagination.skip]);

  async function loadChatLogs() {
    setIsLoading(true);
    setError(null);
    try {
      const data = await fetchChatLogs({ skip: pagination.skip, limit: pagination.limit });
      setChatLogs(data.items);
      setPagination(prev => ({ ...prev, total: data.total }));
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }

  function formatDate(dateString) {
    return new Date(dateString).toLocaleString();
  }

  function getFirstMessage(messages) {
    const userMessage = messages?.find(m => m.role === 'user');
    return userMessage?.content || 'No message';
  }

  function getResponse(messages) {
    const assistantMessage = messages?.find(m => m.role === 'assistant');
    return assistantMessage?.content || 'No response';
  }

  function truncate(text, maxLength = 100) {
    if (!text || text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
  }

  const totalPages = Math.ceil(pagination.total / pagination.limit);
  const currentPage = Math.floor(pagination.skip / pagination.limit) + 1;

  if (isLoading) {
    return (
      <div className="flex justify-center items-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span className="ml-3 text-gray-600">Loading chat history...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg">
        <strong>Error:</strong> {error}
        <button
          onClick={loadChatLogs}
          className="ml-4 text-red-600 underline hover:text-red-800"
        >
          Retry
        </button>
      </div>
    );
  }

  if (chatLogs.length === 0) {
    return (
      <div className="text-center py-12 text-gray-500">
        <p>No chat history found.</p>
        <p className="text-sm mt-2">Start a chat to see conversations here.</p>
      </div>
    );
  }

  return (
    <div>
      <div className="overflow-hidden shadow ring-1 ring-black ring-opacity-5 rounded-lg">
        <table className="min-w-full divide-y divide-gray-300">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Patient MRN
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Date
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Query
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Response
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {chatLogs.map((log) => (
              <tr key={log._id || log.conversation_id} className="hover:bg-gray-50">
                <td className="px-4 py-3 text-sm text-gray-900 font-mono">
                  {log.patient_mrn}
                </td>
                <td className="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">
                  {formatDate(log.started_at)}
                </td>
                <td className="px-4 py-3 text-sm text-gray-900 max-w-xs">
                  {truncate(getFirstMessage(log.messages))}
                </td>
                <td className="px-4 py-3 text-sm text-gray-500 max-w-xs">
                  {truncate(getResponse(log.messages))}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-4">
          <p className="text-sm text-gray-700">
            Showing {pagination.skip + 1} to {Math.min(pagination.skip + pagination.limit, pagination.total)} of{' '}
            {pagination.total} results
          </p>
          <div className="flex space-x-2">
            <button
              onClick={() => setPagination(prev => ({ ...prev, skip: prev.skip - prev.limit }))}
              disabled={currentPage === 1}
              className="px-3 py-1 text-sm border rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
            >
              Previous
            </button>
            <span className="px-3 py-1 text-sm text-gray-600">
              Page {currentPage} of {totalPages}
            </span>
            <button
              onClick={() => setPagination(prev => ({ ...prev, skip: prev.skip + prev.limit }))}
              disabled={currentPage === totalPages}
              className="px-3 py-1 text-sm border rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
