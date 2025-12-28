//  StatsBar.tsx
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-22 at 13:00 (America/Los_Angeles - Pacific Time)
//  Notes: Stats bar component for voice events

'use client'

interface StatsBarProps {
  total: number
  success: number
  failed: number
  llmUsed: number
  pending: number
  successRate: number
}

export default function StatsBar({
  total,
  success,
  failed,
  llmUsed,
  pending,
  successRate,
}: StatsBarProps) {
  return (
    <div className="grid grid-cols-2 md:grid-cols-6 gap-4 mb-6">
      <div className="bg-slate-800 rounded-lg p-4">
        <div className="text-sm text-slate-400">Total</div>
        <div className="text-2xl font-bold text-white">{total}</div>
      </div>
      <div className="bg-slate-800 rounded-lg p-4">
        <div className="text-sm text-slate-400">Success</div>
        <div className="text-2xl font-bold text-green-400">{success}</div>
      </div>
      <div className="bg-slate-800 rounded-lg p-4">
        <div className="text-sm text-slate-400">Failed</div>
        <div className="text-2xl font-bold text-red-400">{failed}</div>
      </div>
      <div className="bg-slate-800 rounded-lg p-4">
        <div className="text-sm text-slate-400">LLM Used</div>
        <div className="text-2xl font-bold text-purple-400">{llmUsed}</div>
      </div>
      <div className="bg-slate-800 rounded-lg p-4">
        <div className="text-sm text-slate-400">Pending</div>
        <div className="text-2xl font-bold text-yellow-400">{pending}</div>
      </div>
      <div className="bg-slate-800 rounded-lg p-4">
        <div className="text-sm text-slate-400">Success Rate</div>
        <div className="text-2xl font-bold text-white">{successRate}%</div>
      </div>
    </div>
  )
}
