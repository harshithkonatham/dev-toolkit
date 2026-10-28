#!/usr/bin/env python3
"""
DevOps CrewAI Team — A crew of specialized AI agents that collaborate
to handle complex DevOps tasks autonomously.

Agents:
  - SRE Lead: Incident management, SLOs, runbooks
  - Security Analyst: Vulnerability scanning, threat modeling
  - Release Engineer: Deployment planning, rollback strategy
  - Cost Optimizer: Cloud spend analysis, right-sizing recommendations

Usage:
    python devops_crew.py --task "Analyze our production incidents from last week and suggest improvements"
    python devops_crew.py --task "Plan the deployment strategy for v2.0 release"
    python devops_crew.py --task "Review our AWS costs and identify savings opportunities"

Dependencies:
    pip install crewai crewai-tools anthropic python-dotenv
"""

import os
import sys
from dotenv import load_dotenv

load_dotenv()

# Use Claude as the LLM backend for CrewAI
os.environ["ANTHROPIC_API_KEY"] = os.getenv("ANTHROPIC_API_KEY", "")

try:
    from crewai import Agent, Crew, Process, Task
    from crewai_tools import FileReadTool, SerperDevTool
except ImportError:
    print("Install crewai: pip install crewai crewai-tools")
    sys.exit(1)

from langchain_anthropic import ChatAnthropic

# Initialize Claude as the LLM
llm = ChatAnthropic(
    model="claude-sonnet-4-6",
    anthropic_api_key=os.getenv("ANTHROPIC_API_KEY"),
    max_tokens=4096,
)


# ─────────────────────────────────────────
# DEFINE AGENTS
# ─────────────────────────────────────────

sre_lead = Agent(
    role="Senior SRE Lead",
    goal=(
        "Ensure production systems are reliable, scalable, and observable. "
        "Analyze incidents, maintain SLOs, and build runbooks."
    ),
    backstory=(
        "You have 12 years of SRE experience at FAANG companies. "
        "You've managed systems serving hundreds of millions of users. "
        "You think in terms of error budgets, toil reduction, and blast radius."
    ),
    verbose=True,
    allow_delegation=True,
    llm=llm,
    tools=[FileReadTool()],
)

security_analyst = Agent(
    role="DevSecOps Security Analyst",
    goal=(
        "Identify security vulnerabilities, misconfigurations, and compliance gaps. "
        "Provide actionable remediation plans prioritized by risk."
    ),
    backstory=(
        "You're a certified security professional (CISSP, CEH) with deep expertise in "
        "cloud security, container security, and supply chain attacks. "
        "You always think like an attacker to find weaknesses before they do."
    ),
    verbose=True,
    allow_delegation=False,
    llm=llm,
)

release_engineer = Agent(
    role="Release Engineering Lead",
    goal=(
        "Plan safe, zero-downtime deployments with clear rollback strategies. "
        "Automate release pipelines and enforce deployment best practices."
    ),
    backstory=(
        "You've shipped thousands of production releases across microservices, "
        "monorepos, and mobile apps. You've built canary deployments, feature flag "
        "systems, and progressive delivery pipelines at scale."
    ),
    verbose=True,
    allow_delegation=False,
    llm=llm,
)

cost_optimizer = Agent(
    role="FinOps Cloud Cost Optimizer",
    goal=(
        "Identify cloud waste, right-size resources, and build cost optimization roadmaps. "
        "Balance performance requirements with cost efficiency."
    ),
    backstory=(
        "You've reduced cloud bills by 40-60% for Fortune 500 companies through "
        "systematic analysis of resource utilization, reserved instance strategies, "
        "and architectural optimizations. You know every AWS/GCP/Azure pricing quirk."
    ),
    verbose=True,
    allow_delegation=False,
    llm=llm,
)


# ─────────────────────────────────────────
# DEFINE TASK TEMPLATES
# ─────────────────────────────────────────

def create_incident_analysis_tasks(context: str) -> list[Task]:
    """Tasks for incident analysis workflow."""
    analyze_task = Task(
        description=f"""
        Analyze the following incident/production issue and provide:
        1. Root cause analysis
        2. Contributing factors
        3. Timeline reconstruction
        4. Impact assessment (users affected, SLO impact)

        Context: {context}

        Output a structured incident report.
        """,
        agent=sre_lead,
        expected_output="Structured incident report with RCA, timeline, and impact assessment",
    )

    security_task = Task(
        description=f"""
        Review the incident from a security perspective:
        1. Was there any security component to this incident?
        2. Could this have been exploited maliciously?
        3. What security controls would have prevented or detected this earlier?

        Context: {context}
        """,
        agent=security_analyst,
        context=[analyze_task],
        expected_output="Security analysis of the incident with recommendations",
    )

    improvement_task = Task(
        description="""
        Based on the incident analysis, create a comprehensive improvement plan:
        1. Immediate fixes (next 24 hours)
        2. Short-term improvements (next sprint)
        3. Long-term architectural changes
        4. Runbook updates needed
        5. Monitoring/alerting gaps to fill
        6. Suggested release process changes to prevent similar incidents

        Create a prioritized action plan with owners and timelines.
        """,
        agent=release_engineer,
        context=[analyze_task, security_task],
        expected_output="Prioritized improvement action plan with owners and timelines",
    )

    return [analyze_task, security_task, improvement_task]


def create_deployment_planning_tasks(context: str) -> list[Task]:
    """Tasks for deployment planning workflow."""
    risk_task = Task(
        description=f"""
        Assess the deployment risk for the following release:
        1. What could go wrong? List top 10 risks
        2. What dependencies need to be verified?
        3. What's the rollback strategy for each risk?

        Context: {context}
        """,
        agent=sre_lead,
        expected_output="Risk assessment with rollback strategies",
    )

    security_review_task = Task(
        description=f"""
        Security review for the deployment:
        1. Any new attack surface introduced?
        2. Secret/credential changes needed?
        3. Security testing requirements before production?
        4. Compliance implications?

        Context: {context}
        """,
        agent=security_analyst,
        expected_output="Security checklist and requirements for deployment",
    )

    deployment_plan_task = Task(
        description="""
        Create a detailed deployment plan:
        1. Step-by-step deployment runbook
        2. Canary/blue-green strategy recommendation
        3. Feature flag configuration
        4. Go/no-go criteria
        5. Monitoring checks to run post-deploy
        6. Communication plan (stakeholder notifications)
        7. Rollback procedure with time estimates

        Make it copy-paste ready for the on-call engineer.
        """,
        agent=release_engineer,
        context=[risk_task, security_review_task],
        expected_output="Complete deployment runbook ready for execution",
    )

    return [risk_task, security_review_task, deployment_plan_task]


def create_cost_analysis_tasks(context: str) -> list[Task]:
    """Tasks for cloud cost optimization workflow."""
    cost_task = Task(
        description=f"""
        Analyze the cloud infrastructure costs and identify optimization opportunities:
        1. Identify top 10 cost drivers
        2. Find idle/underutilized resources
        3. Reserved instance / savings plan opportunities
        4. Architecture-level optimizations

        Context: {context}
        """,
        agent=cost_optimizer,
        expected_output="Cost analysis with top 10 optimization opportunities and estimated savings",
    )

    reliability_impact_task = Task(
        description="""
        Review the proposed cost optimizations from a reliability perspective:
        1. Which optimizations could impact availability/performance?
        2. What's the minimum viable infrastructure for our SLOs?
        3. Where should we NOT cut costs?

        Provide guardrails for the cost optimization initiative.
        """,
        agent=sre_lead,
        context=[cost_task],
        expected_output="Reliability guardrails and approved cost optimizations",
    )

    return [cost_task, reliability_impact_task]


# ─────────────────────────────────────────
# CREW FACTORY
# ─────────────────────────────────────────

def run_crew(task_type: str, context: str) -> str:
    """Run the appropriate crew for the given task type."""
    task_map = {
        "incident": (create_incident_analysis_tasks, [sre_lead, security_analyst, release_engineer]),
        "deployment": (create_deployment_planning_tasks, [sre_lead, security_analyst, release_engineer]),
        "cost": (create_cost_analysis_tasks, [cost_optimizer, sre_lead]),
    }

    # Auto-detect task type from context if not specified
    if task_type == "auto":
        context_lower = context.lower()
        if any(w in context_lower for w in ["incident", "outage", "down", "error rate", "latency"]):
            task_type = "incident"
        elif any(w in context_lower for w in ["deploy", "release", "ship", "rollout"]):
            task_type = "deployment"
        elif any(w in context_lower for w in ["cost", "spend", "bill", "savings", "expensive"]):
            task_type = "cost"
        else:
            task_type = "incident"  # default

    task_factory, agents = task_map.get(task_type, task_map["incident"])
    tasks = task_factory(context)

    crew = Crew(
        agents=agents,
        tasks=tasks,
        process=Process.sequential,
        verbose=True,
        max_rpm=10,  # Rate limit API calls
    )

    result = crew.kickoff()
    return result


def main():
    import argparse

    parser = argparse.ArgumentParser(description="DevOps AI Crew")
    parser.add_argument("--task", required=True, help="Task description")
    parser.add_argument(
        "--type",
        choices=["incident", "deployment", "cost", "auto"],
        default="auto",
        help="Task type (default: auto-detect)",
    )
    args = parser.parse_args()

    print(f"\nLaunching DevOps AI Crew...")
    print(f"Task: {args.task}")
    print(f"Type: {args.type}")
    print("=" * 60)

    result = run_crew(args.type, args.task)

    print("\n" + "=" * 60)
    print("CREW OUTPUT:")
    print("=" * 60)
    print(result)


if __name__ == "__main__":
    main()
