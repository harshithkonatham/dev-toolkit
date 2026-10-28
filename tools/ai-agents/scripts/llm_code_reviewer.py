#!/usr/bin/env python3
"""
AI Code Reviewer — Uses Claude to review GitHub PRs for security, performance,
and best practices. Posts review comments directly on the PR.

Usage:
    python llm_code_reviewer.py --repo owner/repo --pr 42
    python llm_code_reviewer.py --repo owner/repo --pr 42 --model claude-haiku-4-5-20251001

Dependencies:
    pip install anthropic requests python-dotenv
"""

import argparse
import json
import os
import sys
from dataclasses import dataclass
from typing import Optional

import anthropic
import requests
from dotenv import load_dotenv

load_dotenv()

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
DEFAULT_MODEL = "claude-sonnet-4-6"

REVIEW_SYSTEM_PROMPT = """You are an expert senior software engineer conducting a code review.
Your job is to review the provided git diff and give constructive, actionable feedback.

Focus on:
1. **Security vulnerabilities** — SQL injection, XSS, hardcoded secrets, insecure dependencies
2. **Performance issues** — N+1 queries, missing indexes, inefficient algorithms, memory leaks
3. **Best practices** — SOLID principles, DRY, naming conventions, error handling
4. **Testing** — Missing test coverage for critical paths
5. **Documentation** — Missing docstrings on public functions

Format your response as JSON:
{
  "summary": "2-3 sentence overall assessment",
  "severity": "APPROVE | REQUEST_CHANGES | COMMENT",
  "issues": [
    {
      "severity": "critical | major | minor | nitpick",
      "category": "security | performance | best-practice | testing | docs",
      "file": "path/to/file.py",
      "line": 42,
      "issue": "Description of the issue",
      "suggestion": "How to fix it",
      "code_example": "Optional improved code snippet"
    }
  ],
  "positives": ["Things done well in this PR"]
}

Be specific, cite line numbers, and provide concrete suggestions. Skip trivial issues.
"""


@dataclass
class ReviewResult:
    summary: str
    severity: str
    issues: list
    positives: list


def get_pr_diff(repo: str, pr_number: int) -> tuple[str, dict]:
    """Fetch the diff and metadata for a GitHub PR."""
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json",
    }

    # Get PR metadata
    pr_url = f"https://api.github.com/repos/{repo}/pulls/{pr_number}"
    pr_resp = requests.get(pr_url, headers=headers, timeout=30)
    pr_resp.raise_for_status()
    pr_data = pr_resp.json()

    # Get diff
    diff_headers = {**headers, "Accept": "application/vnd.github.v3.diff"}
    diff_resp = requests.get(pr_url, headers=diff_headers, timeout=30)
    diff_resp.raise_for_status()

    return diff_resp.text, pr_data


def review_with_claude(diff: str, pr_title: str, pr_description: str, model: str) -> ReviewResult:
    """Send diff to Claude for review."""
    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

    user_message = f"""Please review this Pull Request:

**Title:** {pr_title}
**Description:** {pr_description or 'No description provided'}

**Diff:**
```diff
{diff[:80000]}  # Truncate to stay within context limits
```

Provide your review in the specified JSON format."""

    message = client.messages.create(
        model=model,
        max_tokens=4096,
        system=REVIEW_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_message}],
    )

    response_text = message.content[0].text

    # Extract JSON from response (handle markdown code blocks)
    if "```json" in response_text:
        response_text = response_text.split("```json")[1].split("```")[0].strip()
    elif "```" in response_text:
        response_text = response_text.split("```")[1].split("```")[0].strip()

    data = json.loads(response_text)
    return ReviewResult(
        summary=data.get("summary", ""),
        severity=data.get("severity", "COMMENT"),
        issues=data.get("issues", []),
        positives=data.get("positives", []),
    )


def post_review_to_github(repo: str, pr_number: int, result: ReviewResult, model: str):
    """Post the review as a GitHub PR review."""
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json",
    }

    # Build review body
    body_lines = [
        f"## AI Code Review (powered by {model})\n",
        f"### Summary\n{result.summary}\n",
    ]

    if result.positives:
        body_lines.append("### What's Done Well")
        for pos in result.positives:
            body_lines.append(f"- {pos}")
        body_lines.append("")

    if result.issues:
        # Group by severity
        critical = [i for i in result.issues if i["severity"] == "critical"]
        major = [i for i in result.issues if i["severity"] == "major"]

        if critical:
            body_lines.append("### Critical Issues")
            for issue in critical:
                body_lines.append(f"- **{issue['file']}:{issue.get('line', '?')}** — {issue['issue']}")
                body_lines.append(f"  > {issue['suggestion']}")
            body_lines.append("")

        if major:
            body_lines.append("### Major Issues")
            for issue in major:
                body_lines.append(f"- **{issue['file']}:{issue.get('line', '?')}** — {issue['issue']}")
            body_lines.append("")

    body_lines.append(
        f"\n---\n*This review was generated automatically. "
        f"Total issues found: {len(result.issues)}. "
        f"Human review is still required before merging.*"
    )

    review_url = f"https://api.github.com/repos/{repo}/pulls/{pr_number}/reviews"
    payload = {
        "body": "\n".join(body_lines),
        "event": result.severity,  # APPROVE, REQUEST_CHANGES, or COMMENT
    }

    resp = requests.post(review_url, headers=headers, json=payload, timeout=30)
    resp.raise_for_status()
    print(f"Review posted: {resp.json()['html_url']}")


def print_review_local(result: ReviewResult):
    """Print review to stdout when not posting to GitHub."""
    print("\n" + "=" * 60)
    print("AI CODE REVIEW RESULTS")
    print("=" * 60)
    print(f"\nVERDICT: {result.severity}")
    print(f"\nSUMMARY:\n{result.summary}")

    if result.positives:
        print("\nPOSITIVES:")
        for pos in result.positives:
            print(f"  + {pos}")

    if result.issues:
        print(f"\nISSUES FOUND: {len(result.issues)}")
        for issue in result.issues:
            severity_icon = {"critical": "🔴", "major": "🟠", "minor": "🟡", "nitpick": "⚪"}.get(
                issue["severity"], "⚪"
            )
            print(f"\n  {severity_icon} [{issue['severity'].upper()}] {issue['category']}")
            print(f"     File: {issue['file']}:{issue.get('line', '?')}")
            print(f"     Issue: {issue['issue']}")
            print(f"     Fix: {issue['suggestion']}")
            if issue.get("code_example"):
                print(f"     Example:\n{issue['code_example']}")
    else:
        print("\nNo issues found!")
    print("=" * 60)


def main():
    parser = argparse.ArgumentParser(description="AI-powered GitHub PR code reviewer")
    parser.add_argument("--repo", required=True, help="GitHub repo in owner/repo format")
    parser.add_argument("--pr", required=True, type=int, help="PR number")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Claude model to use")
    parser.add_argument("--post", action="store_true", help="Post review to GitHub (default: print only)")
    parser.add_argument("--dry-run", action="store_true", help="Print diff only, no API calls")
    args = parser.parse_args()

    if not ANTHROPIC_API_KEY:
        print("Error: ANTHROPIC_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    print(f"Fetching PR #{args.pr} from {args.repo}...")
    diff, pr_data = get_pr_diff(args.repo, args.pr)

    print(f"PR: {pr_data['title']}")
    print(f"Files changed: {pr_data['changed_files']}, +{pr_data['additions']} -{pr_data['deletions']}")

    if args.dry_run:
        print("\nDiff preview (first 2000 chars):")
        print(diff[:2000])
        return

    print(f"\nReviewing with {args.model}...")
    result = review_with_claude(
        diff=diff,
        pr_title=pr_data["title"],
        pr_description=pr_data.get("body", ""),
        model=args.model,
    )

    if args.post:
        if not GITHUB_TOKEN:
            print("Error: GITHUB_TOKEN not set", file=sys.stderr)
            sys.exit(1)
        post_review_to_github(args.repo, args.pr, result, args.model)
    else:
        print_review_local(result)


if __name__ == "__main__":
    main()
