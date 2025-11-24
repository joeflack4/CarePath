// CarePath Frontend Application
import { useState } from 'react';
import TabNav from './components/TabNav';
import ChatHistory from './components/ChatHistory';
import Chat from './components/Chat';

function App() {
  const [activeTab, setActiveTab] = useState('chat');

  // Chat state persists across tab switches
  const [chatState, setChatState] = useState({
    query: '',
    patientMrn: 'P000123',
    llmMode: '',  // Empty string means use server default
    response: null,
    isLoading: false,
    error: null,
  });

  function handleChatStateChange(updates) {
    setChatState(prev => ({ ...prev, ...updates }));
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-4xl mx-auto px-6 py-4">
          <h1 className="text-2xl font-bold text-gray-900">CarePath</h1>
          <p className="text-sm text-gray-500">AI-Powered Health Assistant</p>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-4xl mx-auto px-6 py-6">
        {/* Tab Navigation */}
        <TabNav activeTab={activeTab} onTabChange={setActiveTab} />

        {/* Tab Content */}
        <div className="mt-6">
          {activeTab === 'history' && <ChatHistory />}
          {activeTab === 'chat' && (
            <Chat chatState={chatState} onStateChange={handleChatStateChange} />
          )}
        </div>
      </main>

      {/* Footer */}
      <footer className="mt-auto py-6 text-center text-sm text-gray-400">
        CarePath Demo &copy; {new Date().getFullYear()}
      </footer>
    </div>
  );
}

export default App;
