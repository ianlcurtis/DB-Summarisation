import { useState, useCallback, type KeyboardEvent, type ChangeEvent } from 'react'
import './MessageInput.css'

interface MessageInputProps {
  onSendMessage: (message: string) => void
  isDisabled: boolean
  placeholder?: string
}

function MessageInput({ onSendMessage, isDisabled, placeholder }: MessageInputProps) {
  const [message, setMessage] = useState('')

  const handleSubmit = useCallback(() => {
    const trimmedMessage = message.trim()
    if (trimmedMessage && !isDisabled) {
      onSendMessage(trimmedMessage)
      setMessage('')
    }
  }, [message, isDisabled, onSendMessage])

  const handleKeyDown = useCallback((e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSubmit()
    }
  }, [handleSubmit])

  const handleChange = useCallback((e: ChangeEvent<HTMLTextAreaElement>) => {
    setMessage(e.target.value)
  }, [])

  return (
    <div className="message-input-container">
      <textarea
        className="message-input"
        value={message}
        onChange={handleChange}
        onKeyDown={handleKeyDown}
        placeholder={placeholder || 'Type a message...'}
        disabled={isDisabled}
        rows={1}
      />
      <button
        className="send-button"
        onClick={handleSubmit}
        disabled={isDisabled || !message.trim()}
        aria-label="Send message"
      >
        <svg 
          width="24" 
          height="24" 
          viewBox="0 0 24 24" 
          fill="none" 
          xmlns="http://www.w3.org/2000/svg"
        >
          <path 
            d="M2.01 21L23 12L2.01 3L2 10L17 12L2 14L2.01 21Z" 
            fill="currentColor"
          />
        </svg>
      </button>
    </div>
  )
}

export default MessageInput
