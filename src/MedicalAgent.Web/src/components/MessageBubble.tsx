import ReactMarkdown from 'react-markdown'
import type { Message } from '../App'
import './MessageBubble.css'

interface MessageBubbleProps {
  message: Message
}

function MessageBubble({ message }: MessageBubbleProps) {
  const isUser = message.role === 'user'

  return (
    <div className={`message-bubble ${isUser ? 'user' : 'assistant'}`}>
      <div className="message-avatar">
        {isUser ? '👤' : '🤖'}
      </div>
      <div className="message-content">
        {isUser ? (
          <p>{message.content}</p>
        ) : (
          <ReactMarkdown>{message.content}</ReactMarkdown>
        )}
        <span className="message-time">
          {message.timestamp.toLocaleTimeString()}
        </span>
      </div>
    </div>
  )
}

export default MessageBubble
