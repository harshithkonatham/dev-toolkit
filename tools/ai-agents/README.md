# AI Agents for DevOps Automation

> LLM-powered agents that automate repetitive DevOps, SRE, and engineering workflows.

## Why AI Agents in DevOps?

Modern DevOps teams spend 40%+ of their time on repetitive tasks: reviewing PRs, triaging incidents, writing runbooks, analyzing logs. AI agents (powered by Claude, GPT-4o, or local models via Ollama) can handle these autonomously, reducing toil and accelerating delivery.

## Architecture

```
┌─────────────────────────────────────────┐
│             Trigger Layer               │
│  (GitHub Webhook / Cron / Slack / CLI)  │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│            Agent Orchestrator           │
│   (CrewAI / LangGraph / Claude SDK)     │
└──────────────┬──────────────────────────┘
               │
     ┌─────────┴──────────┐
     │                    │
┌────▼─────┐     ┌────────▼───────┐
│  Tools   │     │  LLM Backend   │
│ (GitHub  │     │ (Claude 4.6 /  │
│  Jira    │     │  Ollama local) │
│  Slack   │     └────────────────┘
│  K8s)    │
└──────────┘
```

## Modules

| Script | Purpose | Trigger |
|--------|---------|---------|
| `scripts/llm_code_reviewer.py` | AI code review on PRs | GitHub webhook |
| `scripts/incident_responder.py` | Auto triage + runbook generation | PagerDuty / Alertmanager |
| `scripts/pr_summarizer.py` | Slack summary of merged PRs | GitHub merge event |
| `scripts/log_analyzer_ai.py` | Root cause analysis from logs | Cron / alert |
| `scripts/infra_advisor.py` | Review Terraform plans for risks | CI pipeline |
| `agents/devops_crew.py` | Full CrewAI DevOps team | CLI / API |
| `agents/sre_agent.py` | Autonomous SRE agent | Event-driven |

## Quick Start

```bash
# Install dependencies
pip install anthropic crewai langchain-anthropic python-dotenv requests

# Set API keys
export ANTHROPIC_API_KEY="sk-ant-..."
export GITHUB_TOKEN="ghp_..."
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."

# Run code reviewer on a PR
python scripts/llm_code_reviewer.py --repo owner/repo --pr 42

# Run incident responder
python scripts/incident_responder.py --alert "High CPU on prod-api-01"

# Launch full DevOps crew
python agents/devops_crew.py --task "Analyze last 24h of production incidents"
```

## Model Selection Guide

| Task | Recommended Model | Why |
|------|------------------|-----|
| Code review | `claude-sonnet-4-6` | Deep code understanding |
| Incident triage | `claude-opus-4-6` | Complex reasoning |
| Log summarization | `claude-haiku-4-5` | Fast, cost-efficient |
| Local/private | `ollama: qwen2.5-coder` | No data leaves machine |
| Long context logs | `claude-sonnet-4-6` | 200k context window |

## Configuration

See `configs/agent_config.yaml` for full configuration options including model selection, tool permissions, notification targets, and rate limiting.

## Real-World Use Cases

1. **Auto PR Review** — Agent reviews code for security issues, performance, and best practices before human review
2. **Incident Runbooks** — When an alert fires, agent generates a step-by-step runbook based on past incidents
3. **Release Notes** — Auto-generates changelog from merged PRs and commits
4. **Cost Anomaly Detection** — Agent monitors cloud spend and notifies when anomalies detected
5. **Dependency Updates** — Agent evaluates Dependabot PRs and auto-merges safe ones
