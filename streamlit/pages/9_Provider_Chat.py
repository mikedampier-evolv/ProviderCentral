"""
Hospital 360 — Cortex Agent (Agentic Analytics)
Multi-step reasoning agent backed by the Hospital 360 semantic view.
Supports auto-SQL generation, execution, and conversational follow-ups.
Uses SSE streaming for real-time thinking and response rendering.
"""

import json
from collections import defaultdict

import numpy as np
import pandas as pd
import requests
import sseclient
import streamlit as st
import chart_theme as ct

st.set_page_config(layout="wide")

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
AGENT_DB = "HOSPITAL360_APP"
AGENT_SCHEMA = "CORTEX_ANALYST"
AGENT_NAME = "HOSPITAL360_AGENT"
API_TIMEOUT = 300  # seconds (streaming can take longer)

# Container runtime: use st.connection instead of get_active_session()
conn = st.connection("snowflake")
session = conn.session()

# Build the REST API base URL from the session's connection
_sf_conn = session.connection
ACCOUNT_URL = f"https://{_sf_conn.host}"
API_ENDPOINT = (
    f"{ACCOUNT_URL}/api/v2/databases/{AGENT_DB}"
    f"/schemas/{AGENT_SCHEMA}/agents/{AGENT_NAME}:run"
)

SAMPLE_QUESTIONS = [
    "What is the 30-day readmission rate by facility?",
    "Which specialties have the highest patient leakage and how much revenue is lost?",
    "How does OR utilization vary across blocks and days of the week?",
    "What are the top denial categories and what is the appeal success rate?",
    "Are there any anomalies in recent denial patterns?",
    "Compare readmission rates and average LOS across all five facilities",
    "What are the busiest surgical days by facility?",
    "Which payers have the highest denial rates?",
]

# ---------------------------------------------------------------------------
# Session state
# ---------------------------------------------------------------------------
if "agent_messages" not in st.session_state:
    st.session_state.agent_messages = []
if "agent_suggestion" not in st.session_state:
    st.session_state.agent_suggestion = None

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------
st.title("Provider Chat")
st.caption(
    "Agentic analytics with multi-step reasoning — "
    "the agent plans, queries, and synthesizes answers automatically"
)

with st.sidebar:
    st.subheader("Hospital 360 Agent")
    st.markdown(f"**Agent:** `{AGENT_NAME}`")
    st.markdown("---")
    st.markdown("**Try asking:**")
    for q in SAMPLE_QUESTIONS:
        if st.button(q, key=f"agent_starter_{hash(q)}", use_container_width=True):
            st.session_state.agent_suggestion = q
    st.markdown("---")
    if st.button("Clear Chat", key="agent_clear", use_container_width=True):
        st.session_state.agent_messages = []
        st.session_state.agent_suggestion = None
        st.rerun()


# ---------------------------------------------------------------------------
# Agent API call (streaming)
# ---------------------------------------------------------------------------
def call_agent_stream(messages):
    """Send messages to Cortex Agent via REST API with streaming enabled."""
    request_body = {"messages": messages}
    token = _sf_conn._rest._token
    resp = requests.post(
        API_ENDPOINT,
        json=request_body,
        headers={
            "Authorization": f'Snowflake Token="{token}"',
            "Content-Type": "application/json",
        },
        stream=True,
        timeout=API_TIMEOUT,
    )
    if resp.status_code < 400:
        return resp, None
    else:
        try:
            parsed = resp.json()
            error_msg = (
                f"**Agent Error** (status {resp.status_code})\n\n"
                f"Request ID: `{parsed.get('request_id', 'N/A')}`\n\n"
                f"```\n{parsed.get('message', json.dumps(parsed, indent=2))}\n```"
            )
        except Exception:
            error_msg = f"**Agent Error** (status {resp.status_code}): {resp.text[:500]}"
        return None, error_msg


# ---------------------------------------------------------------------------
# Stream SSE events and render in real-time
# ---------------------------------------------------------------------------
def stream_events(response):
    """Parse SSE events from the agent response and render progressively.

    Groups thinking, tool_use, and tool_result into a single "Agent Reasoning"
    expander that stays open while streaming and collapses on final response.
    Text deltas and tables/charts render outside the reasoning expander.

    Returns the final response message dict for storing in chat history,
    or None if an error occurred.
    """
    content = st.container()
    # Placeholder for the combined reasoning expander (thinking + tools)
    reasoning_placeholder = content.empty()
    # Ordered log of reasoning steps: list of (label, content_str)
    reasoning_log = []
    # Separate placeholders for text, tables, charts (outside reasoning)
    output_map = defaultdict(content.empty)
    # Text delta buffers
    text_buffers = defaultdict(str)
    # Current thinking buffer
    thinking_buffer = ""
    # Final message to store in session state
    final_message = None

    spinner = st.spinner("Waiting for response...")
    spinner.__enter__()

    def _format_tool_use(data):
        """Format tool_use event as human-readable markdown."""
        tool_name = data.get("name", "unknown")
        tool_input = data.get("input", {})
        lines = [f"Calling **{tool_name}**"]
        if isinstance(tool_input, dict):
            if "query" in tool_input:
                lines.append(f"\n```sql\n{tool_input['query']}\n```")
            elif "sql" in tool_input:
                lines.append(f"\n```sql\n{tool_input['sql']}\n```")
            elif "question" in tool_input:
                lines.append(f'\n> "{tool_input["question"]}"')
            else:
                for k, v in tool_input.items():
                    if isinstance(v, str) and len(v) > 100:
                        lines.append(f"- **{k}**: {v[:100]}...")
                    else:
                        lines.append(f"- **{k}**: {v}")
        return "\n".join(lines)

    def _format_tool_result(data):
        """Format tool_result event as human-readable markdown."""
        content = data.get("content", data.get("result", ""))
        tool_name = data.get("name", "")
        status = data.get("status", "")

        lines = []
        if tool_name:
            lines.append(f"Result from **{tool_name}**")
        if status and status != "success":
            lines.append(f"Status: `{status}`")

        if isinstance(content, list):
            for item in content:
                if isinstance(item, dict):
                    if item.get("type") == "text":
                        lines.append(item.get("text", ""))
                    elif item.get("type") == "sql":
                        sql = item.get("statement", item.get("sql", ""))
                        if sql:
                            lines.append(f"```sql\n{sql}\n```")
                    elif item.get("type") == "result_set":
                        lines.append("*(query results received)*")
                    else:
                        lines.append(f"- {item.get('type', 'data')}: received")
                else:
                    lines.append(str(item)[:200])
        elif isinstance(content, str):
            lines.append(content[:500] if len(content) > 500 else content)
        elif isinstance(content, dict):
            if "text" in content:
                lines.append(content["text"])
            else:
                lines.append("*(data received)*")

        return "\n".join(lines) if lines else "*(completed)*"

    def _render_reasoning(expanded=True):
        """Re-render the thinking expander."""
        with reasoning_placeholder.container():
            with st.expander("Agent Reasoning", expanded=expanded):
                if thinking_buffer:
                    st.markdown(thinking_buffer)

    try:
        events = sseclient.SSEClient(response).events()
        for event in events:
            data_str = event.data

            if event.event == "response.status":
                data = json.loads(data_str)
                spinner.__exit__(None, None, None)
                spinner = st.spinner(data.get("message", "Working..."))
                spinner.__enter__()

            elif event.event == "response.thinking.delta":
                data = json.loads(data_str)
                thinking_buffer += data.get("text", "")
                _render_reasoning(expanded=True)

            elif event.event == "response.thinking":
                data = json.loads(data_str)
                thinking_buffer = data.get("text", thinking_buffer)
                _render_reasoning(expanded=True)

            elif event.event == "response.text.delta":
                data = json.loads(data_str)
                idx = data.get("content_index", 0)
                text_buffers[idx] += data.get("text", "")
                output_map[f"text_{idx}"].markdown(text_buffers[idx])

            elif event.event == "response.tool_use":
                pass  # Hidden from UI

            elif event.event == "response.tool_result":
                pass  # Hidden from UI

            elif event.event == "response.table":
                data = json.loads(data_str)
                idx = data.get("content_index", 0)
                _render_streamed_table(data, output_map[f"table_{idx}"])

            elif event.event == "response.chart":
                data = json.loads(data_str)
                idx = data.get("content_index", 0)
                try:
                    spec = json.loads(data.get("chart_spec", "{}"))
                    output_map[f"chart_{idx}"].vega_lite_chart(
                        spec, use_container_width=True
                    )
                except Exception:
                    pass

            elif event.event == "error":
                data = json.loads(data_str)
                st.error(
                    f"**Error**: {data.get('message', 'Unknown error')} "
                    f"(code: {data.get('code', 'N/A')})"
                )
                if st.session_state.agent_messages:
                    st.session_state.agent_messages.pop()
                spinner.__exit__(None, None, None)
                return None

            elif event.event == "response":
                final_message = json.loads(data_str)

    except Exception as e:
        st.error(f"Streaming error: {e}")

    # Collapse the reasoning expander now that we have the final result
    if thinking_buffer or reasoning_log:
        _render_reasoning(expanded=False)

    spinner.__exit__(None, None, None)
    return final_message


def _render_streamed_table(data, placeholder):
    """Render a table event from the streaming response."""
    result_set = data.get("result_set", {})
    rows = result_set.get("data", [])
    meta = result_set.get("result_set_meta_data", {})
    row_types = meta.get("row_type", [])

    if rows:
        column_names = [col.get("name", f"col_{i}") for i, col in enumerate(row_types)]
        try:
            df = pd.DataFrame(np.array(rows), columns=column_names)
            # Try to convert numeric columns
            for col in df.columns:
                try:
                    df[col] = pd.to_numeric(df[col])
                except (ValueError, TypeError):
                    pass
            with placeholder.container():
                title = data.get("title")
                if title:
                    st.markdown(f"**{title}**")
                st.dataframe(df, use_container_width=True)

                # Auto-chart for small result sets
                numeric_cols = df.select_dtypes(include="number").columns.tolist()
                non_numeric = [c for c in df.columns if c not in numeric_cols]
                if numeric_cols and non_numeric and len(df) <= 50:
                    import plotly.express as px
                    fig = px.bar(
                        df, x=non_numeric[0], y=numeric_cols[0],
                        title=f"{numeric_cols[0]} by {non_numeric[0]}"
                    )
                    ct.apply_style(fig, height=350)
                    ct.style_bars(fig)
                    st.plotly_chart(fig, use_container_width=True)
        except Exception:
            placeholder.json(rows)


# ---------------------------------------------------------------------------
# Replay stored content from chat history
# ---------------------------------------------------------------------------
def display_stored_content(content_items, msg_idx):
    """Render stored agent response content for chat history replay.

    Groups thinking, tool_use, and tool_result into a single collapsed
    'Agent Reasoning' expander. Text, tables, and charts render outside.
    """
    if not isinstance(content_items, list):
        return

    # Collect reasoning items vs output items in order
    reasoning_items = []
    output_items = []
    for item in content_items:
        if not isinstance(item, dict):
            continue
        item_type = item.get("type", "")
        if item_type == "thinking":
            reasoning_items.append(item)
        elif item_type in ("tool_use", "tool_result"):
            pass  # Hidden from UI
        else:
            output_items.append(item)

    # Render the combined reasoning expander (collapsed in history)
    if reasoning_items:
        with st.expander("Agent Reasoning", expanded=False):
            for item in reasoning_items:
                text = item.get("text", "")
                if text:
                    st.markdown(text)

    # Render output items (text, tables, charts, suggestions)
    for i, item in enumerate(output_items):
        item_type = item.get("type", "")

        if item_type == "text":
            st.markdown(item.get("text", ""))

        elif item_type == "table":
            table_data = item.get("table", item)
            _render_streamed_table(table_data, st)

        elif item_type == "chart":
            chart_data = item.get("chart", item)
            try:
                spec = json.loads(chart_data.get("chart_spec", "{}"))
                st.vega_lite_chart(spec, use_container_width=True)
            except Exception:
                pass

        elif item_type == "suggested_queries":
            queries = item.get("suggested_queries", item.get("queries", []))
            if queries:
                st.markdown("**Suggested follow-ups:**")
                for j, q in enumerate(queries):
                    text = q.get("query", q) if isinstance(q, dict) else q
                    if st.button(text, key=f"hist_sug_{msg_idx}_{j}"):
                        st.session_state.agent_suggestion = text


# ---------------------------------------------------------------------------
# Process user question
# ---------------------------------------------------------------------------
def process_agent_question(prompt):
    """Process a user question through Cortex Agent with streaming."""
    user_msg = {"role": "user", "content": [{"type": "text", "text": prompt}]}
    st.session_state.agent_messages.append(user_msg)

    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        # Build conversation history for the API
        api_messages = []
        for msg in st.session_state.agent_messages:
            role = msg["role"]
            if role == "user":
                api_messages.append(msg)
            elif role == "assistant":
                api_messages.append({
                    "role": "assistant",
                    "content": msg["content"],
                })

        with st.spinner("Sending request..."):
            response, error = call_agent_stream(api_messages)

        if error:
            st.error(error)
            assistant_msg = {
                "role": "assistant",
                "content": [{"type": "text", "text": error}],
            }
        else:
            final_message = stream_events(response)
            if final_message:
                assistant_msg = {
                    "role": "assistant",
                    "content": final_message.get("content", []),
                    "request_id": final_message.get("request_id"),
                }
            else:
                # Error occurred during streaming; message already popped
                return

    st.session_state.agent_messages.append(assistant_msg)


# ---------------------------------------------------------------------------
# Chat history
# ---------------------------------------------------------------------------
for idx, msg in enumerate(st.session_state.agent_messages):
    role = msg["role"]
    display_role = "user" if role == "user" else "assistant"
    with st.chat_message(display_role):
        if role == "user":
            st.markdown(msg["content"][0]["text"])
        else:
            display_stored_content(msg["content"], idx)

# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------
user_input = st.chat_input("Ask the Hospital 360 Agent a question...")

if user_input:
    process_agent_question(user_input)
    st.rerun()
elif st.session_state.agent_suggestion:
    suggestion = st.session_state.agent_suggestion
    st.session_state.agent_suggestion = None
    process_agent_question(suggestion)
    st.rerun()
