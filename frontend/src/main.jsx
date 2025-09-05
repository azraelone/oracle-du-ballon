import React from 'react'
import { createRoot } from 'react-dom/client'

function App() {
  return (
    <main style={{fontFamily: 'system-ui, sans-serif', padding: 24}}>
      <h1>Oracle du Ballon — Frontend</h1>
      <p>VITE_API_BASE_URL = {import.meta.env.VITE_API_BASE_URL}</p>
      <p>Ça tourne 🎉</p>
    </main>
  )
}

createRoot(document.getElementById('root')).render(<App />)
