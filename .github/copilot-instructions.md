---
description: "DevOps & Developer Toolkit Documentation Standards - Ensure comprehensive, up-to-date tool guides with analysis and proper organization"
applyTo: "**/*.md"
---

# ak-dev-toolkit Documentation Standards

## Core Principles
When working with DevOps and developer tool documentation in this repository:

### 1. Comprehensive Setup Coverage
- **Always include** installation instructions for macOS, Linux, and Windows
- **Specify versions** - use latest stable releases (2026+ where applicable)
- **Provide alternatives** - mention popular alternatives and when to choose each
- **Include verification** - add commands to verify successful installation

### 2. Tool Analysis & Context
- **Suitability analysis** - explain when and why to use each tool
- **Strengths/weaknesses** - provide balanced assessment
- **Integration points** - show how tools work together in the stack
- **2026 updates** - highlight modern features and best practices

### 3. Folder Organization
- **One folder per tool** - dedicated directory for each tool's documentation
- **README.md required** - every tool folder must have comprehensive README
- **Sub-folders for complexity** - use sub-folders for advanced topics (setup/, examples/, analysis/)
- **Consistent naming** - use lowercase, hyphen-separated names

### 4. Documentation Quality
- **Step-by-step guides** - break down complex setups into clear steps
- **Code examples** - include working code snippets and commands
- **Troubleshooting** - anticipate common issues and solutions
- **Links & references** - provide official docs and additional resources

## Enforcement Level
This is a **strong preference** - suggest improvements for incomplete documentation but don't block creation. Flag missing elements like "Consider adding installation verification commands" or "This tool analysis could include integration examples".

## Examples to Follow
- `tools/devops/docker/README.md` - comprehensive with multi-stage builds, best practices
- `tools/devops/kubernetes/README.md` - covers installation, security, operations
- `tools/developer/git/README.md` - branching strategies, advanced commands

## When This Applies
- Creating new tool documentation
- Updating existing guides
- Reviewing PRs for documentation changes
- Any .md file in tools/, setup/, or documentation folders