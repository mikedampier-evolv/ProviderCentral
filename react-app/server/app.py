import os
import json
from flask import Flask, request, jsonify, Response, stream_with_context, send_from_directory
from flask_cors import CORS
from dotenv import load_dotenv
import requests as http_requests

# Local dev only. In the container there is no .env and this silently no-ops --
# Cloud Run supplies the same names as env vars (SNOWFLAKE_PAT from Secret
# Manager, the rest as plain values).
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

# The built SPA. Same relative path locally (react-app/dist) and in the image
# (/app/dist), because the Dockerfile keeps server/ and dist/ as siblings.
DIST_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'dist'))

# static_folder=None: Flask's built-in static handler is disabled so the SPA
# catch-all at the bottom of this file is the single path for serving files.
app = Flask(__name__, static_folder=None)

# Only matters for local dev, where Vite serves the UI on :5173 and proxies
# /api here. In the container both are same-origin and this is a no-op.
CORS(app)

SNOWFLAKE_ACCOUNT = os.environ.get("SNOWFLAKE_ACCOUNT")
SNOWFLAKE_WAREHOUSE = os.environ.get("SNOWFLAKE_WAREHOUSE", "DEMO_WH")
SNOWFLAKE_ROLE = os.environ.get("SNOWFLAKE_ROLE", "UNIFAI_USER")
SNOWFLAKE_DATABASE = os.environ.get("SNOWFLAKE_DATABASE", "HOSPITAL_360")
SNOWFLAKE_PAT = os.environ.get("SNOWFLAKE_PAT")

ALLOWED_ROLES = {"UNIFAI_USER", "H360_ANALYST", "H360_CLINICIAN", "H360_FINANCE", "H360_EXEC"}

BASE_URL = f"https://{SNOWFLAKE_ACCOUNT}"


@app.route("/api/sql", methods=["POST"])
def execute_sql():
    """Execute SQL via Snowflake SQL REST API using PAT."""
    body = request.get_json()
    sql = body.get("sql")
    if not sql:
        return jsonify({"error": "Missing 'sql' in request body"}), 400

    # Map frontend role to actual Snowflake role
    ROLE_MAP = {
        'H360_CLINICIAN': 'H360_CLINICIAN',
        'H360_FINANCE': 'H360_FINANCE',
        'H360_EXEC': 'H360_EXEC',
    }
    req_role = body.get("role", "H360_CLINICIAN")
    effective_role = ROLE_MAP.get(req_role, 'H360_CLINICIAN')

    try:
        resp = http_requests.post(
            f"{BASE_URL}/api/v2/statements",
            json={
                "statement": sql,
                "warehouse": SNOWFLAKE_WAREHOUSE,
                "database": SNOWFLAKE_DATABASE,
                "role": effective_role,
            },
            headers={
                "Authorization": f"Bearer {SNOWFLAKE_PAT}",
                "Content-Type": "application/json",
                "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN",
            },
            timeout=30,
        )
        resp.raise_for_status()
        result = resp.json()

        # Poll for async completion if needed
        if result.get("statementStatusUrl") and result.get("code") != "090001":
            import time
            for _ in range(60):
                time.sleep(1)
                poll = http_requests.get(
                    f"{BASE_URL}{result['statementStatusUrl']}",
                    headers={
                        "Authorization": f"Bearer {SNOWFLAKE_PAT}",
                        "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN",
                    },
                    timeout=10,
                )
                result = poll.json()
                if result.get("code") == "090001":
                    break

        # Transform to rows, converting types based on metadata
        row_type = result.get("resultSetMetaData", {}).get("rowType", [])
        columns = [col["name"] for col in row_type]
        col_types = [col.get("type", "").upper() for col in row_type]
        raw_data = result.get("data", [])

        from datetime import date, datetime, timedelta

        def convert_value(val, col_type):
            if val is None:
                return None
            if col_type == "DATE":
                try:
                    return str(date(1970, 1, 1) + timedelta(days=int(val)))
                except (ValueError, TypeError):
                    return val
            if col_type in ("TIMESTAMP_NTZ", "TIMESTAMP_LTZ", "TIMESTAMP_TZ"):
                try:
                    # Snowflake returns timestamps as fractional seconds since epoch
                    ts = float(val)
                    return datetime.utcfromtimestamp(ts / 1e9 if ts > 1e12 else ts).isoformat()
                except (ValueError, TypeError):
                    return val
            if col_type == "BOOLEAN":
                return val.lower() in ("true", "1", "yes") if isinstance(val, str) else bool(val)
            if col_type in ("FIXED", "REAL", "FLOAT"):
                try:
                    # Return as number if it looks like one
                    if "." in str(val):
                        return float(val)
                    return int(val)
                except (ValueError, TypeError):
                    return val
            return val

        rows = []
        for row in raw_data:
            obj = {}
            for i, val in enumerate(row):
                obj[columns[i]] = convert_value(val, col_types[i] if i < len(col_types) else "")
            rows.append(obj)

        return jsonify({"data": rows})

    except http_requests.HTTPError as e:
        error_body = e.response.json() if e.response else str(e)
        print(f"SQL error: {error_body}")
        return jsonify({"error": error_body}), 500
    except Exception as e:
        print(f"SQL error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/api/agent", methods=["POST"])
def proxy_agent():
    """Proxy SSE stream to Cortex Agent."""
    body = request.get_json()
    messages = body.get("messages", [])

    agent_url = f"{BASE_URL}/api/v2/databases/HOSPITAL_360/schemas/CORTEX_ANALYST/agents/HOSPITAL360_AGENT:run"

    try:
        resp = http_requests.post(
            agent_url,
            json={"messages": messages},
            headers={
                "Authorization": f"Bearer {SNOWFLAKE_PAT}",
                "Content-Type": "application/json",
                "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN",
                "Accept": "text/event-stream",
            },
            stream=True,
            timeout=300,
        )
        resp.raise_for_status()

        def generate():
            for chunk in resp.iter_content(chunk_size=None):
                if chunk:
                    yield chunk

        return Response(
            stream_with_context(generate()),
            content_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "Connection": "keep-alive"},
        )

    except Exception as e:
        print(f"Agent error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/api/email", methods=["POST"])
def send_email():
    """Send email via Snowflake SYSTEM$SEND_EMAIL."""
    body = request.get_json()
    to = body.get("to")
    subject = body.get("subject", "Provider 360 Chat Results")
    email_body = body.get("body", "")

    if not to:
        return jsonify({"error": "Missing 'to' in request body"}), 400
    if not email_body:
        return jsonify({"error": "Missing 'body' in request body"}), 400

    # Escape single quotes and newlines for SQL string literals
    to_escaped = to.replace("'", "''")
    subject_escaped = subject.replace("'", "''")
    body_escaped = email_body.replace("\\", "\\\\").replace("'", "''").replace("\n", "\\n").replace("\r", "")

    sql = f"CALL SYSTEM$SEND_EMAIL('H360_EMAIL_INT', '{to_escaped}', '{subject_escaped}', '{body_escaped}')"

    print(f"Email request: to={to}, subject={subject}, body_len={len(email_body)}")

    try:
        resp = http_requests.post(
            f"{BASE_URL}/api/v2/statements",
            json={
                "statement": sql,
                "warehouse": SNOWFLAKE_WAREHOUSE,
                "database": SNOWFLAKE_DATABASE,
                "role": SNOWFLAKE_ROLE,
            },
            headers={
                "Authorization": f"Bearer {SNOWFLAKE_PAT}",
                "Content-Type": "application/json",
                "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN",
            },
            timeout=30,
        )
        resp.raise_for_status()
        result = resp.json()

        # Poll for async completion if needed
        import time
        if result.get("statementStatusUrl") and result.get("code") != "090001":
            for _ in range(30):
                time.sleep(1)
                poll = http_requests.get(
                    f"{BASE_URL}{result['statementStatusUrl']}",
                    headers={
                        "Authorization": f"Bearer {SNOWFLAKE_PAT}",
                        "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN",
                    },
                    timeout=10,
                )
                result = poll.json()
                if result.get("code") == "090001":
                    break

        # Check for error in result
        if result.get("message") and "error" in result.get("message", "").lower():
            return jsonify({"error": result.get("message")}), 500

        return jsonify({"success": True, "message": f"Email sent to {to}"})

    except http_requests.HTTPError as e:
        error_body = e.response.json() if e.response else str(e)
        print(f"Email error: {error_body}")
        return jsonify({"error": error_body}), 500
    except Exception as e:
        print(f"Email error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/api/alert", methods=["POST"])
def create_alert():
    """Create a Snowflake Alert via SQL REST API."""
    import re
    import time

    # Metric presets: metric_key -> SQL template (use {threshold} placeholder)
    METRIC_PRESETS = {
        "readmission_rate": {
            "name": "HIGH_READMISSION_RATE",
            "condition_gt": "SELECT 1 FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS HAVING AVG(READMIT_30_FLAG::INT) * 100 > {threshold}",
            "condition_lt": "SELECT 1 FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS HAVING AVG(READMIT_30_FLAG::INT) * 100 < {threshold}",
        },
        "avg_los": {
            "name": "HIGH_AVG_LOS",
            "condition_gt": "SELECT 1 FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS HAVING AVG(LOS_DAYS) > {threshold}",
            "condition_lt": "SELECT 1 FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS HAVING AVG(LOS_DAYS) < {threshold}",
        },
        "or_utilization": {
            "name": "LOW_OR_UTILIZATION",
            "condition_gt": "SELECT 1 FROM HOSPITAL_360.OPERATIONS.MART_OR_CAPACITY HAVING AVG(UTILIZATION_PCT) > {threshold}",
            "condition_lt": "SELECT 1 FROM HOSPITAL_360.OPERATIONS.MART_OR_CAPACITY HAVING AVG(UTILIZATION_PCT) < {threshold}",
        },
        "overtime_pct": {
            "name": "HIGH_OVERTIME",
            "condition_gt": "SELECT 1 FROM HOSPITAL_360.WORKFORCE.MART_STAFFING_QUALITY HAVING AVG(OT_PCT) > {threshold}",
            "condition_lt": "SELECT 1 FROM HOSPITAL_360.WORKFORCE.MART_STAFFING_QUALITY HAVING AVG(OT_PCT) < {threshold}",
        },
        "denial_rate": {
            "name": "HIGH_DENIAL_RATE",
            "condition_gt": "SELECT 1 FROM HOSPITAL_360.FINANCIAL.MART_DENIALS_REVCYCLE HAVING SUM(CASE WHEN CLAIM_STATUS='DENIED' THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0) > {threshold}",
            "condition_lt": "SELECT 1 FROM HOSPITAL_360.FINANCIAL.MART_DENIALS_REVCYCLE HAVING SUM(CASE WHEN CLAIM_STATUS='DENIED' THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0) < {threshold}",
        },
        "operating_margin": {
            "name": "LOW_OPERATING_MARGIN",
            "condition_gt": "SELECT 1 FROM HOSPITAL_360.FINANCIAL.MART_FINANCIAL_PERFORMANCE HAVING AVG(OPERATING_MARGIN)*100 > {threshold}",
            "condition_lt": "SELECT 1 FROM HOSPITAL_360.FINANCIAL.MART_FINANCIAL_PERFORMANCE HAVING AVG(OPERATING_MARGIN)*100 < {threshold}",
        },
    }

    body = request.get_json()
    metric = body.get("metric", "").strip()
    threshold = body.get("threshold", "")
    operator = body.get("operator", "exceeds")  # "exceeds" or "falls_below"
    condition = body.get("condition", "").strip()  # raw SQL fallback
    name = body.get("name", "").strip()
    email = body.get("email", "").strip()
    schedule = body.get("schedule", "60")  # minutes

    if not email:
        return jsonify({"error": "Missing 'email' for alert notification"}), 400

    # Build condition from metric preset or raw SQL
    if metric and metric in METRIC_PRESETS:
        preset = METRIC_PRESETS[metric]
        try:
            thresh_val = float(threshold)
        except (ValueError, TypeError):
            return jsonify({"error": "Invalid threshold value"}), 400
        cond_key = "condition_gt" if operator == "exceeds" else "condition_lt"
        condition = preset[cond_key].format(threshold=thresh_val)
        if not name:
            name = preset["name"]
    elif not condition:
        return jsonify({"error": "Missing metric selection or condition SQL"}), 400

    if not name:
        return jsonify({"error": "Missing 'name' for the alert"}), 400

    # Sanitize alert name (alphanumeric + underscores only)
    safe_name = re.sub(r'[^a-zA-Z0-9_]', '_', name).upper()

    # Escape values for SQL
    email_escaped = email.replace("'", "''")

    # Build CREATE ALERT SQL
    alert_sql = f"""CREATE OR REPLACE ALERT HOSPITAL_360.ALERTS.{safe_name}
  WAREHOUSE = {SNOWFLAKE_WAREHOUSE}
  SCHEDULE = '{schedule} MINUTE'
  IF (EXISTS (
    {condition}
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL('H360_EMAIL_INT', '{email_escaped}', 'Provider 360 Alert: {safe_name}', 'Alert condition met. Please review in Provider 360 dashboard.')"""

    try:
        # Create the alert
        resp = http_requests.post(
            f"{BASE_URL}/api/v2/statements",
            json={
                "statement": alert_sql,
                "warehouse": SNOWFLAKE_WAREHOUSE,
                "database": SNOWFLAKE_DATABASE,
                "role": SNOWFLAKE_ROLE,
            },
            headers={
                "Authorization": f"Bearer {SNOWFLAKE_PAT}",
                "Content-Type": "application/json",
                "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN",
            },
            timeout=30,
        )
        resp.raise_for_status()
        result = resp.json()

        # Poll for completion
        if result.get("statementStatusUrl") and result.get("code") != "090001":
            for _ in range(30):
                time.sleep(1)
                poll = http_requests.get(
                    f"{BASE_URL}{result['statementStatusUrl']}",
                    headers={
                        "Authorization": f"Bearer {SNOWFLAKE_PAT}",
                        "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN",
                    },
                    timeout=10,
                )
                result = poll.json()
                if result.get("code") == "090001":
                    break

        if "error" in result.get("message", "").lower():
            return jsonify({"error": result.get("message")}), 500

        # Resume the alert (alerts are suspended on creation)
        resume_sql = f"ALTER ALERT HOSPITAL_360.ALERTS.{safe_name} RESUME"
        resp2 = http_requests.post(
            f"{BASE_URL}/api/v2/statements",
            json={
                "statement": resume_sql,
                "warehouse": SNOWFLAKE_WAREHOUSE,
                "database": SNOWFLAKE_DATABASE,
                "role": SNOWFLAKE_ROLE,
            },
            headers={
                "Authorization": f"Bearer {SNOWFLAKE_PAT}",
                "Content-Type": "application/json",
                "X-Snowflake-Authorization-Token-Type": "PROGRAMMATIC_ACCESS_TOKEN",
            },
            timeout=30,
        )
        resp2.raise_for_status()

        return jsonify({
            "success": True,
            "message": f"Alert '{safe_name}' created and activated (runs every {schedule} min)",
            "alert_name": safe_name,
        })

    except http_requests.HTTPError as e:
        error_body = e.response.json() if e.response else str(e)
        print(f"Alert error: {error_body}")
        return jsonify({"error": error_body}), 500
    except Exception as e:
        print(f"Alert error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def serve_spa(path):
    """Serve the built SPA, falling back to index.html for client-side routes.

    Flask matches the explicit /api/* rules above before this one -- static
    segments outrank a <path:> converter regardless of definition order -- so
    this only ever sees UI traffic. The explicit guard below is belt and braces:
    without it an unknown /api/typo would render index.html with a 200, and a
    fetch would fail on unexpected HTML rather than a clean 404.
    """
    if path.startswith("api/"):
        return jsonify({"error": "Not found"}), 404

    if path and os.path.isfile(os.path.join(DIST_DIR, path)):
        return send_from_directory(DIST_DIR, path)

    # Deep links like /readmission are routes inside BrowserRouter, not files.
    return send_from_directory(DIST_DIR, "index.html")


if __name__ == "__main__":
    # Local dev entrypoint only -- the container runs gunicorn (see Dockerfile).
    # PORT is read rather than hardcoded because Cloud Run assigns it, and the
    # cf-access-proxy sidecar moves the app to 8081 once attached.
    port = int(os.environ.get("PORT", 3001))
    print(f"Flask proxy running on http://localhost:{port}")
    print(f"Connected to: {BASE_URL}")
    app.run(host="0.0.0.0", port=port, debug=False, threaded=True)
