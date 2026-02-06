import { useState, useCallback } from 'react'
import './App.css'
import ChatWindow from './components/ChatWindow'
import MessageInput from './components/MessageInput'
import { sendMessage, sendConversationMessage } from './services/api'

export interface Message {
  id: string
  role: 'user' | 'assistant'
  content: string
  timestamp: Date
}

function App() {
  const [messages, setMessages] = useState<Message[]>([])
  const [conversationId, setConversationId] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [useConversation, setUseConversation] = useState(true)

  const handleSendMessage = useCallback(async (content: string) => {
    const userMessage: Message = {
      id: crypto.randomUUID(),
      role: 'user',
      content,
      timestamp: new Date()
    }
    
    setMessages(prev => [...prev, userMessage])
    setIsLoading(true)

    try {
      let response: string
      
      if (useConversation) {
        const result = await sendConversationMessage(content, conversationId)
        response = result.response
        setConversationId(result.conversationId)
      } else {
        response = await sendMessage(content)
      }

      const assistantMessage: Message = {
        id: crypto.randomUUID(),
        role: 'assistant',
        content: response,
        timestamp: new Date()
      }
      
      setMessages(prev => [...prev, assistantMessage])
    } catch (error) {
      const errorMessage: Message = {
        id: crypto.randomUUID(),
        role: 'assistant',
        content: `Error: ${error instanceof Error ? error.message : 'Failed to get response'}`,
        timestamp: new Date()
      }
      setMessages(prev => [...prev, errorMessage])
    } finally {
      setIsLoading(false)
    }
  }, [conversationId, useConversation])

  const handleNewConversation = useCallback(() => {
    setMessages([])
    setConversationId(null)
  }, [])

  return (
    <div className="app">
      <header className="app-header">
        <h1>🏥 Medical Agent Chat</h1>
        <div className="header-controls">
          <label className="toggle-label">
            <input
              type="checkbox"
              checked={useConversation}
              onChange={(e) => setUseConversation(e.target.checked)}
            />
            Multi-turn conversation
          </label>
          <button 
            className="new-chat-button"
            onClick={handleNewConversation}
          >
            New Chat
          </button>
        </div>
      </header>
      
      <main className="app-main">
        <ChatWindow messages={messages} isLoading={isLoading} />
        <MessageInput 
          onSendMessage={handleSendMessage} 
          isDisabled={isLoading}
          placeholder="Ask about patient medical history..."
        />
      </main>
      
      <footer className="app-footer">
        <p>Connected to Medical Agent API • {useConversation && conversationId ? `Session: ${conversationId.slice(0, 8)}...` : 'Single-turn mode'}</p>
      </footer>
    </div>
  )
}

export default App
