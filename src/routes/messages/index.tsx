import React from 'react'
import { Routes, Route } from 'react-router-dom'
import MessageList from './MessageList'
import BatchEditor from './BatchEditor'

export default function MessagesRoutes() {
  console.log('MessagesRoutes rendering')
  return (
    <Routes>
      <Route index element={<MessageList />} />
      <Route path="batch" element={<BatchEditor />} />
    </Routes>
  )
} 