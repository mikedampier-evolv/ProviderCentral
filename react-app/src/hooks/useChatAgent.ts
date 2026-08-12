import { useState, useCallback, useRef } from "react";

export interface Message {
  role: "user" | "assistant";
  content: string;
  thinking?: string;
  charts?: string[];  // Array of Vega-Lite JSON spec strings
}

export function useChatAgent() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isStreaming, setIsStreaming] = useState(false);
  const [emailStatus, setEmailStatus] = useState<string | null>(null);
  const [alertStatus, setAlertStatus] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const sendMessage = useCallback(
    async (text: string) => {
      const userMessage: Message = { role: "user", content: text };
      setMessages((prev) => [...prev, userMessage]);
      setIsStreaming(true);

      const history = [...messages, userMessage].map((m) => ({
        role: m.role,
        content: [{ type: "text", text: m.content }],
      }));

      abortRef.current = new AbortController();

      try {
        const response = await fetch("/api/agent", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ messages: history }),
          signal: abortRef.current.signal,
        });

        if (!response.ok) {
          throw new Error(`Agent request failed: ${response.status}`);
        }

        const reader = response.body?.getReader();
        if (!reader) throw new Error("No response body");

        const decoder = new TextDecoder();
        let assistantText = "";
        let thinkingText = "";
        let charts: string[] = [];
        let buffer = "";

        setMessages((prev) => [...prev, { role: "assistant", content: "", thinking: "", charts: [] }]);

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() ?? "";

          let currentEvent = "";
          for (const line of lines) {
            if (line.startsWith("event:")) {
              currentEvent = line.slice(6).trim();
            } else if (line.startsWith("data:")) {
              const jsonStr = line.slice(5).trim();
              if (!jsonStr || jsonStr === "[DONE]") continue;

              try {
                const event = JSON.parse(jsonStr);

                // DEBUG: Log all SSE events to console
                console.log(`[SSE] event: ${currentEvent}`, event);

                if (currentEvent === "response.text.delta") {
                  const delta = event.text ?? "";
                  if (delta) {
                    assistantText += delta;
                    setMessages((prev) => {
                      const updated = [...prev];
                      updated[updated.length - 1] = {
                        role: "assistant",
                        content: assistantText,
                        thinking: thinkingText, charts,
                      };
                      return updated;
                    });
                  }
                } else if (currentEvent === "response.thinking.delta") {
                  const delta = event.text ?? "";
                  if (delta) {
                    thinkingText += delta;
                    setMessages((prev) => {
                      const updated = [...prev];
                      updated[updated.length - 1] = {
                        role: "assistant",
                        content: assistantText,
                        thinking: thinkingText, charts,
                      };
                      return updated;
                    });
                  }
                } else if (currentEvent === "response.status") {
                  const status = event.message ?? "";
                  if (status) {
                    thinkingText += `\n🔄 ${status}`;
                    setMessages((prev) => {
                      const updated = [...prev];
                      updated[updated.length - 1] = {
                        role: "assistant",
                        content: assistantText,
                        thinking: thinkingText, charts,
                      };
                      return updated;
                    });
                  }
                } else if (currentEvent === "response.tool_use") {
                  const toolName = event.name ?? "tool";
                  const input = event.input ?? {};
                  let toolLine = `\n🔧 Using **${toolName}**`;
                  if (input.sql) toolLine += `\n\`\`\`sql\n${input.sql}\n\`\`\``;
                  thinkingText += toolLine;
                  setMessages((prev) => {
                    const updated = [...prev];
                    updated[updated.length - 1] = {
                      role: "assistant",
                      content: assistantText,
                      thinking: thinkingText, charts,
                    };
                    return updated;
                  });
                } else if (currentEvent === "response.chart") {
                  const chartSpec = event.chart_spec;
                  if (chartSpec) {
                    charts = [...charts, chartSpec];
                    setMessages((prev) => {
                      const updated = [...prev];
                      updated[updated.length - 1] = {
                        role: "assistant",
                        content: assistantText,
                        thinking: thinkingText, charts,
                      };
                      return updated;
                    });
                  }
                }
              } catch {
                // Skip unparseable
              }
            }
          }
        }

        if (!assistantText && !thinkingText) {
          setMessages((prev) => {
            const updated = [...prev];
            updated[updated.length - 1] = {
              role: "assistant",
              content: "I processed your question but didn't generate a response. Try rephrasing.",
            };
            return updated;
          });
        }
      } catch (err: any) {
        if (err.name !== "AbortError") {
          console.error("Chat agent error:", err);
          setMessages((prev) => [
            ...prev.slice(0, -1),
            { role: "assistant", content: "Error: " + err.message },
          ]);
        }
      } finally {
        setIsStreaming(false);
        abortRef.current = null;
      }
    },
    [messages]
  );

  const sendEmail = useCallback(
    async (to: string, messageContent: string) => {
      setEmailStatus("sending");
      try {
        const resp = await fetch("/api/email", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            to,
            subject: "Provider 360 Chat Results",
            body: messageContent,
          }),
        });
        if (!resp.ok) {
          const err = await resp.json();
          const msg = typeof err.error === 'string' ? err.error : err.error?.message || `Email failed: ${resp.status}`;
          throw new Error(msg);
        }
        setEmailStatus("sent");
        setTimeout(() => setEmailStatus(null), 3000);
      } catch (err: any) {
        console.error("Email error:", err);
        setEmailStatus("error");
        setTimeout(() => setEmailStatus(null), 3000);
      }
    },
    []
  );

  const createAlert = useCallback(
    async (params: { metric: string; threshold: string; operator: string; email: string; schedule: string }) => {
      setAlertStatus("creating");
      try {
        const resp = await fetch("/api/alert", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(params),
        });
        if (!resp.ok) {
          const err = await resp.json();
          const msg = typeof err.error === 'string' ? err.error : err.error?.message || `Alert failed: ${resp.status}`;
          throw new Error(msg);
        }
        setAlertStatus("created");
        setTimeout(() => setAlertStatus(null), 4000);
      } catch (err: any) {
        console.error("Alert error:", err);
        setAlertStatus("error");
        setTimeout(() => setAlertStatus(null), 4000);
      }
    },
    []
  );

  const clearMessages = useCallback(() => {
    if (abortRef.current) abortRef.current.abort();
    setMessages([]);
  }, []);

  return { messages, sendMessage, isStreaming, clearMessages, sendEmail, emailStatus, createAlert, alertStatus };
}
