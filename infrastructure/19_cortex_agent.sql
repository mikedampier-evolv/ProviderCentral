/*==============================================================================
  HOSPITAL 360 — Week 7: Cortex Agent
  Creates a Cortex Agent object backed by the Week 6 semantic view.

  The agent uses:
    - cortex_analyst_text_to_sql : converts NL questions to SQL via semantic view
      (As of Apr 2026, the agent generates SQL directly without a separate sql_exec tool)
    - execution_environment : warehouse H360_BI_WH for query execution

  Target: HOSPITAL360_APP.CORTEX_ANALYST.HOSPITAL360_AGENT
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE H360_BI_WH;

-- Ensure CREATE AGENT privilege exists on schema
GRANT CREATE AGENT ON SCHEMA HOSPITAL360_APP.CORTEX_ANALYST TO ROLE SYSADMIN;

CREATE OR REPLACE AGENT HOSPITAL360_APP.CORTEX_ANALYST.HOSPITAL360_AGENT
    COMMENT = 'Hospital 360 agentic analytics — multi-step reasoning across readmissions, leakage, OR capacity, denials, and ML predictions'
    PROFILE = '{"display_name": "Hospital 360 Agent", "color": "blue"}'
    FROM SPECIFICATION
    $$
    models:
      orchestration: auto

    orchestration:
      budget:
        seconds: 60
        tokens: 16000

    instructions:
      system: >
        You are the Hospital 360 Analytics Agent — an expert healthcare data analyst.
        You have access to structured data covering five hospital facilities across
        four domains: (1) readmission & length-of-stay analysis, (2) patient referral
        leakage, (3) operating room capacity & utilization, and (4) claim denials &
        revenue cycle. You also have ML prediction data for encounter volume forecasting
        and denial anomaly detection. Data spans July 2023 through December 2024.
      response: >
        Provide concise, actionable answers. When presenting data, highlight key
        takeaways first, then supporting details. Use bullet points for clarity.
        When comparing facilities, specialties, or time periods, note both absolute
        values and percentages. Always specify the time period covered by results.
        If the user asks a question outside the available data domains, say so clearly.
      orchestration: >
        For any question about readmissions, length of stay, patient leakage, referrals,
        OR utilization, surgical capacity, claim denials, revenue cycle, encounter forecasts,
        or denial anomalies — use the Hospital360Analyst tool. For multi-part questions,
        break them into subtasks and address each one. If results seem unexpected,
        verify by running a sanity check query.
      sample_questions:
        - question: "What is the 30-day readmission rate by facility?"
          answer: "I'll query the readmission data grouped by facility to get this for you."
        - question: "Which specialties have the highest patient leakage and how much revenue is lost?"
          answer: "I'll analyze referral leakage by specialty with revenue impact."
        - question: "How does OR utilization vary across blocks and days of the week?"
          answer: "I'll break down OR utilization by block and day of week to find patterns."
        - question: "What are the top denial categories and what is the appeal success rate?"
          answer: "I'll look at denial volumes by category and calculate appeal win rates."
        - question: "Are there any anomalies in recent denial patterns?"
          answer: "I'll check the ML anomaly detection results for unusual denial activity."
        - question: "Compare readmission rates and average LOS across all five facilities"
          answer: "I'll pull facility-level metrics for readmission rates and LOS indices."

    tools:
      - tool_spec:
          type: "cortex_analyst_text_to_sql"
          name: "Hospital360Analyst"
          description: >
            Analyzes structured hospital data across readmissions & LOS, patient leakage,
            OR capacity & utilization, claim denials & revenue cycle, encounter volume
            forecasts, and denial anomaly detection. Covers 5 facilities, 300K+ records,
            data from July 2023 to December 2024. Use for any quantitative healthcare
            analytics question.

    tool_resources:
      Hospital360Analyst:
        semantic_view: "HOSPITAL360_APP.SEMANTIC_VIEWS.HOSPITAL360_ANALYTICS"
        execution_environment:
          type: "warehouse"
          warehouse: "H360_BI_WH"

    tool_unable_to_answer: >
      I don't have data available to answer that question. My data covers hospital
      readmissions, patient leakage, OR capacity, claim denials, and related ML
      predictions for July 2023 through December 2024.
    $$
;

-- Verify creation
DESCRIBE AGENT HOSPITAL360_APP.CORTEX_ANALYST.HOSPITAL360_AGENT;

-- ---------------------------------------------------------------------------
-- Access control: grant USAGE on agent to all H360 roles
-- ---------------------------------------------------------------------------
GRANT USAGE ON AGENT HOSPITAL360_APP.CORTEX_ANALYST.HOSPITAL360_AGENT
    TO ROLE H360_ANALYST;
GRANT USAGE ON AGENT HOSPITAL360_APP.CORTEX_ANALYST.HOSPITAL360_AGENT
    TO ROLE H360_CLINICIAN;
GRANT USAGE ON AGENT HOSPITAL360_APP.CORTEX_ANALYST.HOSPITAL360_AGENT
    TO ROLE H360_EXEC;
GRANT USAGE ON AGENT HOSPITAL360_APP.CORTEX_ANALYST.HOSPITAL360_AGENT
    TO ROLE H360_FINANCE;
