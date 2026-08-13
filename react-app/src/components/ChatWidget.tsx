import { useState, useRef, useEffect } from 'react';
import { useChatAgent } from '../hooks/useChatAgent';
import VegaChart from './VegaChart';

const sampleQuestions = [
  'What is the current readmission rate?',
  'Which departments have high patient leakage?',
  'Show me OR utilization trends',
  'What are the top denial categories?',
];

export default function ChatWidget() {
  const [open, setOpen] = useState(false);
  const [input, setInput] = useState('');
  const [size, setSize] = useState({ width: 400, height: 600 });
  const [emailTarget, setEmailTarget] = useState<{ index: number; address: string } | null>(null);
  const [alertTarget, setAlertTarget] = useState<{ index: number; metric: string; threshold: string; operator: string; email: string; schedule: string } | null>(null);
  const { messages, sendMessage, isStreaming, clearMessages, sendEmail, emailStatus, createAlert, alertStatus } = useChatAgent();
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const thinkingRef = useRef<HTMLPreElement>(null);
  const resizingRef = useRef<{ startX: number; startY: number; startW: number; startH: number } | null>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  useEffect(() => {
    if (thinkingRef.current) {
      thinkingRef.current.scrollTop = thinkingRef.current.scrollHeight;
    }
  });

  const handleSend = (text?: string) => {
    const msg = text ?? input.trim();
    if (!msg || isStreaming) return;

    // Detect "email to <address>" pattern
    const emailMatch = msg.match(/(?:email|send)\s+(?:this\s+)?(?:to\s+)?([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})/i);
    if (emailMatch) {
      const address = emailMatch[1];
      const lastAssistant = [...messages].reverse().find((m) => m.role === 'assistant');
      if (lastAssistant) {
        sendEmail(address, lastAssistant.content);
        setInput('');
        return;
      }
    }

    sendMessage(msg);
    setInput('');
  };

  const handleEmailClick = (msgIndex: number) => {
    setEmailTarget({ index: msgIndex, address: '' });
  };

  const handleEmailSubmit = () => {
    if (!emailTarget || !emailTarget.address.trim()) return;
    const msg = messages[emailTarget.index];
    if (msg) {
      sendEmail(emailTarget.address.trim(), msg.content);
    }
    setEmailTarget(null);
  };

  const handleAlertClick = (msgIndex: number) => {
    setAlertTarget({ index: msgIndex, metric: 'readmission_rate', threshold: '15', operator: 'exceeds', email: '', schedule: '60' });
  };

  const handleAlertSubmit = () => {
    if (!alertTarget || !alertTarget.metric || !alertTarget.threshold || !alertTarget.email.trim()) return;
    createAlert({
      metric: alertTarget.metric,
      threshold: alertTarget.threshold,
      operator: alertTarget.operator,
      email: alertTarget.email.trim(),
      schedule: alertTarget.schedule,
    });
    setAlertTarget(null);
  };

  const handleResizeStart = (e: React.MouseEvent) => {
    e.preventDefault();
    resizingRef.current = { startX: e.clientX, startY: e.clientY, startW: size.width, startH: size.height };
    const handleMouseMove = (ev: MouseEvent) => {
      if (!resizingRef.current) return;
      const dw = resizingRef.current.startX - ev.clientX;
      const dh = resizingRef.current.startY - ev.clientY;
      setSize({
        width: Math.max(320, Math.min(800, resizingRef.current.startW + dw)),
        height: Math.max(400, Math.min(900, resizingRef.current.startH + dh)),
      });
    };
    const handleMouseUp = () => {
      resizingRef.current = null;
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
  };

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="fixed bottom-6 right-6 z-50 w-14 h-14 rounded-full bg-[#D15635] text-white flex items-center justify-center shadow-lg hover:scale-105 transition-transform"
      >
        <svg width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
          <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z" />
        </svg>
      </button>
    );
  }

  return (
    <div
      className="fixed bottom-6 right-6 z-50 flex flex-col rounded-xl border border-[#D15635] bg-white shadow-2xl"
      style={{ width: `${size.width}px`, height: `${size.height}px` }}
    >
      {/* Resize handle (top-left corner) */}
      <div
        onMouseDown={handleResizeStart}
        className="absolute top-0 left-0 w-4 h-4 cursor-nw-resize z-10"
        title="Drag to resize"
      >
        <svg className="w-3 h-3 m-0.5 text-gray-600" viewBox="0 0 10 10" fill="currentColor">
          <circle cx="2" cy="2" r="1" />
          <circle cx="5" cy="2" r="1" />
          <circle cx="2" cy="5" r="1" />
        </svg>
      </div>
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 rounded-t-xl bg-[#F0EDE8] border-b border-[#D15635]">
        <span className="text-[#D15635] font-semibold text-sm">Provider Chat</span>
        <div className="flex gap-2">
          <button onClick={clearMessages} className="text-gray-500 hover:text-gray-900 text-xs">
            Clear
          </button>
          <button onClick={() => setOpen(false)} className="text-gray-500 hover:text-gray-900">
            <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-3 space-y-3">
        {messages.length === 0 && (
          <div className="space-y-2">
            <p className="text-gray-600 text-sm">Ask a question about the data:</p>
            {sampleQuestions.map((q) => (
              <button
                key={q}
                onClick={() => handleSend(q)}
                className="block w-full text-left text-sm px-3 py-2 rounded-lg border border-[#D15635] text-gray-700 hover:border-[#D15635] hover:text-gray-900 transition-colors"
              >
                {q}
              </button>
            ))}
          </div>
        )}
        {messages.map((msg, i) => (
          <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div
              className={`max-w-[85%] rounded-lg text-sm ${
                msg.role === 'user'
                  ? 'bg-[#D15635] text-white px-3 py-2'
                  : 'bg-[#F5F2ED] text-gray-900 border border-[#D15635] px-3 py-2'
              }`}
            >
              {msg.role === 'assistant' && msg.thinking && (
                <details className="mb-2" open={isStreaming && i === messages.length - 1}>
                  <summary className="text-xs text-gray-600 cursor-pointer hover:text-gray-900 flex items-center gap-1.5">
                    {isStreaming && i === messages.length - 1 ? (
                      <>
                        <svg className="w-3 h-3 animate-spin" viewBox="0 0 24 24" fill="none">
                          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" />
                          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                        </svg>
                        <span>Thinking...</span>
                      </>
                    ) : (
                      <span>Show reasoning</span>
                    )}
                  </summary>
                  <pre ref={isStreaming && i === messages.length - 1 ? thinkingRef : undefined} className="mt-1 text-xs text-gray-500 whitespace-pre-wrap overflow-x-auto max-h-48 overflow-y-auto">
                    {msg.thinking}
                  </pre>
                </details>
              )}
              <div className="whitespace-pre-wrap">
                {msg.content || (isStreaming && i === messages.length - 1 ? '...' : '')}
              </div>
              {msg.charts && msg.charts.length > 0 && (
                <div className="mt-2 space-y-2">
                  {msg.charts.map((spec, ci) => (
                    <VegaChart key={ci} spec={spec} />
                  ))}
                </div>
              )}
              {/* Action buttons for assistant messages */}
              {msg.role === 'assistant' && msg.content && !isStreaming && (
                <div className="mt-2 pt-1 border-t border-[#D15635] space-y-2">
                  {/* Email form */}
                  {emailTarget?.index === i ? (
                    <div className="flex items-center gap-1">
                      <input
                        type="email"
                        value={emailTarget.address}
                        onChange={(e) => setEmailTarget({ ...emailTarget, address: e.target.value })}
                        onKeyDown={(e) => e.key === 'Enter' && handleEmailSubmit()}
                        placeholder="email@example.com"
                        className="flex-1 bg-white border border-[#D4CFC8] rounded px-2 py-1 text-xs text-gray-900 placeholder-gray-400 focus:outline-none focus:border-[#D15635]"
                        autoFocus
                      />
                      <button
                        onClick={handleEmailSubmit}
                        className="text-xs px-2 py-1 rounded bg-[#D15635] text-white hover:bg-[#D4510E]"
                      >
                        Send
                      </button>
                      <button
                        onClick={() => setEmailTarget(null)}
                        className="text-xs px-1 py-1 text-gray-500 hover:text-gray-900"
                      >
                        Cancel
                      </button>
                    </div>
                  ) : alertTarget?.index === i ? (
                    /* Alert form - metric picker */
                    <div className="space-y-1.5">
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs text-gray-600 whitespace-nowrap">Alert me when</span>
                        <select
                          value={alertTarget.metric}
                          onChange={(e) => {
                            const m = e.target.value;
                            const defaults: Record<string, { op: string; thresh: string }> = {
                              readmission_rate: { op: 'exceeds', thresh: '15' },
                              avg_los: { op: 'exceeds', thresh: '5' },
                              or_utilization: { op: 'falls_below', thresh: '60' },
                              overtime_pct: { op: 'exceeds', thresh: '10' },
                              denial_rate: { op: 'exceeds', thresh: '8' },
                              operating_margin: { op: 'falls_below', thresh: '5' },
                            };
                            const d = defaults[m] || { op: 'exceeds', thresh: '10' };
                            setAlertTarget({ ...alertTarget, metric: m, operator: d.op, threshold: d.thresh });
                          }}
                          className="flex-1 bg-white border border-[#D4CFC8] rounded px-2 py-1 text-xs text-gray-900 focus:outline-none focus:border-[#D15635]"
                        >
                          <option value="readmission_rate">Readmission Rate (%)</option>
                          <option value="avg_los">Avg Length of Stay (days)</option>
                          <option value="or_utilization">OR Utilization (%)</option>
                          <option value="overtime_pct">Overtime (%)</option>
                          <option value="denial_rate">Denial Rate (%)</option>
                          <option value="operating_margin">Operating Margin (%)</option>
                        </select>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <select
                          value={alertTarget.operator}
                          onChange={(e) => setAlertTarget({ ...alertTarget, operator: e.target.value })}
                          className="bg-white border border-[#D4CFC8] rounded px-2 py-1 text-xs text-gray-900 focus:outline-none focus:border-[#D15635]"
                        >
                          <option value="exceeds">exceeds</option>
                          <option value="falls_below">falls below</option>
                        </select>
                        <input
                          type="number"
                          value={alertTarget.threshold}
                          onChange={(e) => setAlertTarget({ ...alertTarget, threshold: e.target.value })}
                          className="w-16 bg-white border border-[#D4CFC8] rounded px-2 py-1 text-xs text-gray-900 focus:outline-none focus:border-[#D15635]"
                        />
                      </div>
                      <input
                        type="email"
                        value={alertTarget.email}
                        onChange={(e) => setAlertTarget({ ...alertTarget, email: e.target.value })}
                        placeholder="Notify email address"
                        className="w-full bg-white border border-[#D4CFC8] rounded px-2 py-1 text-xs text-gray-900 placeholder-gray-400 focus:outline-none focus:border-[#D15635]"
                      />
                      <div className="flex items-center gap-2">
                        <select
                          value={alertTarget.schedule}
                          onChange={(e) => setAlertTarget({ ...alertTarget, schedule: e.target.value })}
                          className="bg-white border border-[#D4CFC8] rounded px-2 py-1 text-xs text-gray-900 focus:outline-none focus:border-[#D15635]"
                        >
                          <option value="60">Check every 1 hour</option>
                          <option value="360">Check every 6 hours</option>
                          <option value="720">Check every 12 hours</option>
                          <option value="1440">Check every 24 hours</option>
                        </select>
                        <button
                          onClick={handleAlertSubmit}
                          className="text-xs px-2 py-1 rounded bg-[#f59e0b] text-black font-medium hover:bg-[#d97706]"
                        >
                          Create
                        </button>
                        <button
                          onClick={() => setAlertTarget(null)}
                          className="text-xs px-1 py-1 text-gray-500 hover:text-gray-900"
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  ) : (
                    /* Action buttons row */
                    <div className="flex items-center gap-3">
                      <button
                        onClick={() => handleEmailClick(i)}
                        className="flex items-center gap-1 text-xs text-gray-500 hover:text-[#D15635] transition-colors"
                        title="Email this response"
                      >
                        <svg className="w-3 h-3" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                          <path d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                        </svg>
                        Email
                      </button>
                      <button
                        onClick={() => handleAlertClick(i)}
                        className="flex items-center gap-1 text-xs text-gray-500 hover:text-[#f59e0b] transition-colors"
                        title="Create a Snowflake Alert"
                      >
                        <svg className="w-3 h-3" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                          <path d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                        </svg>
                        Alert
                      </button>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        ))}
        {/* Email status toast */}
        {emailStatus && (
          <div className={`text-xs text-center py-1 rounded ${
            emailStatus === 'sending' ? 'text-yellow-600' :
            emailStatus === 'sent' ? 'text-green-600' :
            'text-red-600'
          }`}>
            {emailStatus === 'sending' ? 'Sending email...' :
             emailStatus === 'sent' ? 'Email sent successfully!' :
             'Failed to send email'}
          </div>
        )}
        {/* Alert status toast */}
        {alertStatus && (
          <div className={`text-xs text-center py-1 rounded ${
            alertStatus === 'creating' ? 'text-yellow-600' :
            alertStatus === 'created' ? 'text-green-600' :
            'text-red-600'
          }`}>
            {alertStatus === 'creating' ? 'Creating Snowflake Alert...' :
             alertStatus === 'created' ? 'Alert created and activated!' :
             'Failed to create alert'}
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="rounded-b-xl bg-[#F0EDE8] border-t border-[#D15635] px-4 py-3">
        <div className="flex gap-2">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSend()}
            placeholder="Ask about your data..."
            className="flex-1 bg-white border border-[#D15635] rounded-lg px-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-[#D15635]"
          />
          <button
            onClick={() => handleSend()}
            disabled={isStreaming || !input.trim()}
            className="px-3 py-2 rounded-lg bg-[#D15635] text-white text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Send
          </button>
        </div>
      </div>
    </div>
  );
}
