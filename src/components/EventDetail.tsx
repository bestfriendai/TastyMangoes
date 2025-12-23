//  EventDetail.tsx
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-22 at 13:00 (America/Los_Angeles - Pacific Time)
//  Notes: Event detail panel component

'use client'

import { VoiceEvent } from '@/lib/supabase'

interface EventDetailProps {
  event: VoiceEvent
  onClose: () => void
}

export default function EventDetail({ event, onClose }: EventDetailProps) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-slate-800 rounded-lg p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-bold text-white">Voice Event Details</h2>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white"
          >
            ✕
          </button>
        </div>
        <div className="space-y-3 text-sm">
          <div>
            <span className="text-slate-400">Utterance:</span>{' '}
            <span className="text-white">{event.utterance}</span>
          </div>
          <div>
            <span className="text-slate-400">Result:</span>{' '}
            <span className="text-white">{event.handler_result || 'N/A'}</span>
          </div>
          <div>
            <span className="text-slate-400">Intent:</span>{' '}
            <span className="text-white">{event.intent || 'N/A'}</span>
          </div>
          <div>
            <span className="text-slate-400">Confidence:</span>{' '}
            <span className="text-white">
              {event.confidence_score ? `${Math.round(event.confidence_score * 100)}%` : 'N/A'}
            </span>
          </div>
          <div>
            <span className="text-slate-400">LLM Used:</span>{' '}
            <span className="text-white">{event.llm_used ? 'Yes' : 'No'}</span>
          </div>
          <div>
            <span className="text-slate-400">Created:</span>{' '}
            <span className="text-white">
              {new Date(event.created_at).toLocaleString()}
            </span>
          </div>
        </div>
      </div>
    </div>
  )
}
