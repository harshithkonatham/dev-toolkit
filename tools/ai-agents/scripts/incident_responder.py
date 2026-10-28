#!/usr/bin/env python3
"""
AI Incident Responder — Automatically triages alerts, generates runbooks,
queries recent deployments/logs, and posts to Slack with actionable steps.

Integrates with: PagerDuty, Alertmanager, Datadog, Slack, GitHub

Usage:
    python incident_responder.py --alert "High error rate on checkout-service"
    python incident_responder.py --webhook  # Run as webhook server

Dependencies:
    pip install anthropic requests python-dotenv flask
"""

import json
import os
import sys
from datetime import datetime, timedelta
from typing import Optional

import anthropic
import requests
from dotenv import load_dotenv

load_dotenv()

client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
SLACK_WEBHOOK = os.getenv("SLACK_WEBHOOK_URL")
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_ORG = os.getenv("GITHUB_ORG", "your-org")

INCIDENT_SYSTEM_PROMPT = """You are an expert SRE (Site Reliability Engineer) with 10+ years of experience.
When given an incident alert, you:
1. Identify the most likely root causes (ranked by probability)
2. Generate a step-by-step runbook for immediate response
3. Suggest monitoring queries to confirm the hypothesis
4. Recommend rollback or mitigation steps
5. Identify which team/service owner should be paged

Format your response as JSON:
{
  "severity": "P1 | P2 | P3 | P4",
  "incident_title": "Short descriptive title",
  "likely_causes": [
    {"probability": "high | medium | low", "cause": "Description", "reasoning": "Why this is likely"}
  ],
  "immediate_actions": [
    {"step": 1, "action": "What to do", "command": "Optional shell command", "expected_outcome": "What you should see"}
  ],
  "investigation_queries": [
    {"tool": "kubectl | datadog | grafana | elk", "query": "The query to run", "purpose": "What to look for"}
  ],
  "escalation": {
    "team": "Team name",
    "page_immediately": true,
    "reason": "Why to escalate"
  },
  "mitigation": "Short-term fix description",
  "prevention": "Long-term fix to prevent recurrence"
}
"""


def get_recent_deployments(service: str, hours: int = 2) -> list[dict]:
    """Fetch recent GitHub deployments for context."""
    if not GITHUB_TOKEN:
        return []

    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json",
    }

    # Search across repos in the org for recent deployments
    url = f"https://api.github.com/orgs/{GITHUB_ORG}/repos"
    resp = requests.get(url, headers=headers, params={"per_page": 10}, timeout=10)
    if not resp.ok:
        return []

    deployments = []
    since = (datetime.utcnow() - timedelta(hours=hours)).isoformat() + "Z"

    for repo in resp.json():
        if service.lower() not in repo["name"].lower():
            continue
        deploy_url = f"https://api.github.com/repos/{GITHUB_ORG}/{repo['name']}/deployments"
        deploy_resp = requests.get(
            deploy_url, headers=headers, params={"per_page": 5}, timeout=10
        )
        if deploy_resp.ok:
            for d in deploy_resp.json():
                if d["created_at"] > since:
                    deployments.append({
                        "repo": repo["name"],
                        "environment": d["environment"],
                        "deployed_at": d["created_at"],
                        "sha": d["sha"][:8],
                        "deployer": d.get("creator", {}).get("login", "unknown"),
                    })

    return deployments


def analyze_incident(alert_text: str, context: Optional[str] = None) -> dict:
    """Use Claude to analyze the incident and generate response plan."""
    deployment_context = ""
    # Try to extract service name from alert
    service_hint = alert_text.split()[0].lower() if alert_text else ""
    recent_deploys = get_recent_deployments(service_hint)

    if recent_deploys:
        deployment_context = f"\n\nRecent deployments in the last 2 hours:\n{json.dumps(recent_deploys, indent=2)}"

    user_message = f"""INCIDENT ALERT: {alert_text}

Timestamp: {datetime.utcnow().isoformat()}Z
{f'Additional context: {context}' if context else ''}
{deployment_context}

Analyze this incident and provide a complete response plan."""

    message = client.messages.create(
        model="claude-opus-4-6",  # Use most capable model for P1 incidents
        max_tokens=3000,
        system=INCIDENT_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_message}],
    )

    response_text = message.content[0].text
    if "```json" in response_text:
        response_text = response_text.split("```json")[1].split("```")[0].strip()
    elif "```" in response_text:
        response_text = response_text.split("```")[1].split("```")[0].strip()

    return json.loads(response_text)


def format_slack_message(alert: str, analysis: dict) -> dict:
    """Format analysis as a rich Slack message with blocks."""
    severity_emoji = {"P1": "🔴", "P2": "🟠", "P3": "🟡", "P4": "🟢"}.get(analysis["severity"], "⚪")

    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"{severity_emoji} {analysis['severity']} — {analysis['incident_title']}",
            },
        },
        {"type": "divider"},
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"*Alert:* {alert}\n*Time:* {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC",
            },
        },
        {"type": "divider"},
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": "*Likely Causes:*"},
        },
    ]

    # Add causes
    cause_text = ""
    for cause in analysis.get("likely_causes", [])[:3]:
        prob_emoji = {"high": "🔴", "medium": "🟡", "low": "🟢"}.get(cause["probability"], "⚪")
        cause_text += f"{prob_emoji} *[{cause['probability'].upper()}]* {cause['cause']}\n"
    blocks.append({"type": "section", "text": {"type": "mrkdwn", "text": cause_text}})

    # Immediate actions
    blocks.append({
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Immediate Actions:*"},
    })
    actions_text = ""
    for action in analysis.get("immediate_actions", [])[:5]:
        actions_text += f"*{action['step']}.* {action['action']}\n"
        if action.get("command"):
            actions_text += f"   `{action['command']}`\n"
    blocks.append({"type": "section", "text": {"type": "mrkdwn", "text": actions_text}})

    # Escalation
    if analysis.get("escalation", {}).get("page_immediately"):
        blocks.append({
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"⚠️ *Page immediately:* @{analysis['escalation']['team']} — {analysis['escalation']['reason']}",
            },
        })

    blocks.append({"type": "divider"})
    blocks.append({
        "type": "context",
        "elements": [
            {
                "type": "mrkdwn",
                "text": "Powered by AI Incident Responder | Review and verify all steps before executing",
            }
        ],
    })

    return {"blocks": blocks}


def post_to_slack(message: dict):
    """Post message to Slack."""
    if not SLACK_WEBHOOK:
        print("Warning: SLACK_WEBHOOK_URL not set, skipping Slack notification")
        return
    resp = requests.post(SLACK_WEBHOOK, json=message, timeout=10)
    resp.raise_for_status()
    print("Slack notification sent successfully")


def print_analysis(alert: str, analysis: dict):
    """Pretty print analysis to terminal."""
    severity_colors = {"P1": "\033[91m", "P2": "\033[93m", "P3": "\033[33m", "P4": "\033[32m"}
    reset = "\033[0m"
    color = severity_colors.get(analysis["severity"], "")

    print(f"\n{'='*70}")
    print(f"{color}INCIDENT RESPONSE PLAN — {analysis['severity']}{reset}")
    print(f"{'='*70}")
    print(f"\nAlert: {alert}")
    print(f"Title: {analysis['incident_title']}")

    print("\n--- LIKELY CAUSES ---")
    for cause in analysis.get("likely_causes", []):
        print(f"  [{cause['probability'].upper()}] {cause['cause']}")
        print(f"         {cause['reasoning']}")

    print("\n--- IMMEDIATE ACTIONS ---")
    for action in analysis.get("immediate_actions", []):
        print(f"  {action['step']}. {action['action']}")
        if action.get("command"):
            print(f"     $ {action['command']}")
        if action.get("expected_outcome"):
            print(f"     Expected: {action['expected_outcome']}")

    print("\n--- INVESTIGATION QUERIES ---")
    for query in analysis.get("investigation_queries", []):
        print(f"  [{query['tool'].upper()}] {query['purpose']}")
        print(f"     {query['query']}")

    escalation = analysis.get("escalation", {})
    if escalation.get("page_immediately"):
        print(f"\n--- ESCALATE IMMEDIATELY ---")
        print(f"  Team: {escalation['team']}")
        print(f"  Reason: {escalation['reason']}")

    print(f"\nMitigation: {analysis.get('mitigation', 'N/A')}")
    print(f"Prevention: {analysis.get('prevention', 'N/A')}")
    print(f"{'='*70}\n")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="AI-powered incident responder")
    parser.add_argument("--alert", help="Alert text to analyze")
    parser.add_argument("--context", help="Additional context (recent changes, service info)")
    parser.add_argument("--slack", action="store_true", help="Post to Slack")
    parser.add_argument(
        "--webhook", action="store_true", help="Run as HTTP webhook server (port 8080)"
    )
    args = parser.parse_args()

    if args.webhook:
        # Run as a webhook server for Alertmanager / PagerDuty integration
        from flask import Flask, jsonify, request

        app = Flask(__name__)

        @app.route("/webhook", methods=["POST"])
        def webhook():
            data = request.json
            # Handle Alertmanager format
            alerts = data.get("alerts", [data])
            for alert_data in alerts:
                alert_text = alert_data.get("annotations", {}).get(
                    "summary", alert_data.get("message", str(alert_data))
                )
                analysis = analyze_incident(alert_text)
                slack_msg = format_slack_message(alert_text, analysis)
                post_to_slack(slack_msg)
            return jsonify({"status": "processed"})

        print("Starting webhook server on port 8080...")
        app.run(host="0.0.0.0", port=8080)
        return

    if not args.alert:
        parser.print_help()
        sys.exit(1)

    print(f"Analyzing incident: {args.alert}")
    analysis = analyze_incident(args.alert, args.context)
    print_analysis(args.alert, analysis)

    if args.slack:
        slack_msg = format_slack_message(args.alert, analysis)
        post_to_slack(slack_msg)


if __name__ == "__main__":
    main()
