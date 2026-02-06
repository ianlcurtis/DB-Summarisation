import { useEffect, useRef } from 'react'
import type { Message } from '../App'
import MessageBubble from './MessageBubble'
import './ChatWindow.css'

interface ChatWindowProps {
  messages: Message[]
  isLoading: boolean
}

function ChatWindow({ messages, isLoading }: ChatWindowProps) {
  const messagesEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, isLoading])

  return (
    <div className="chat-window">
      {messages.length === 0 && !isLoading && (
        <div className="welcome-message">
          <h2>Welcome to Medical Agent Chat</h2>
          <p>Ask questions about patient medical history. Try:</p>
          <ul>
            <li>"What is the complete medical history for patient 1?"</li>
            <li>"What medications is patient 2 currently taking?"</li>
            <li>"What allergies does patient 3 have?"</li>
            <li>"Show me recent lab results for patient 1"</li>
          </ul>
        </div>
      )}
      
      {messages.map((message) => (
        <MessageBubble key={message.id} message={message} />
      ))}
      
      {isLoading && (
        <div className="loading-indicator">
          <div className="loading-dots">
            <span></span>
            <span></span>
            <span></span>
          </div>
          <span>Thinking...</span>
        </div>
      )}
      
      <div ref={messagesEndRef} />
    </div>
  )
}

export default ChatWindow
