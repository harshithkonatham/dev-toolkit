# AI Tools — Complete Reference & Setup Guide

A comprehensive guide to AI tools for coding, automation, local inference, and agentic workflows.
Updated: April 2026.

---

## Table of Contents

1. [AI Coding Assistants](#1-ai-coding-assistants)
2. [Local LLM Runners](#2-local-llm-runners)
3. [AI Agent Frameworks](#3-ai-agent-frameworks)
4. [LLM APIs & SDKs](#4-llm-apis--sdks)
5. [RAG & Knowledge Tools](#5-rag--knowledge-tools)
6. [MCP Servers](#6-mcp-servers)
7. [AI Image & Media Tools](#7-ai-image--media-tools)
8. [Observability & Evaluation](#8-observability--evaluation)
9. [Local Setup Configs](#9-local-setup-configs)

---

## 1. AI Coding Assistants

### Claude Code (Anthropic)
**Best for**: Autonomous coding tasks, agentic workflows, large codebases.

```bash
# Install
npm install -g @anthropic-ai/claude-code

# Run in any project
claude

# Headless / non-interactive (CI mode)
claude --print "Summarize this codebase"

# Use a specific model
claude --model claude-opus-4-6

# MCP server mode
claude mcp serve
```

**Key features**:
- Full file system access (read/edit/write)
- Git-aware context
- MCP server integration
- Extended thinking (Opus 4.6)
- Background agents via SDK

**Config** (`~/.claude/settings.json`):
```json
{
  "model": "claude-sonnet-4-6",
  "permissions": {
    "allow": ["Bash", "Edit", "Write"],
    "deny": []
  },
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-..."
  }
}
```

---

### Cursor
**Best for**: AI-first IDE, inline code generation, multi-file edits.

```bash
# Install via website: https://cursor.com
# macOS via brew
brew install --cask cursor

# CLI open
cursor .
```

**Key settings** (`.cursorrules` in project root):
```
You are an expert TypeScript developer.
Always use async/await over callbacks.
Prefer functional components in React.
Use Zod for validation.
```

**Models available**: Claude 3.5/4, GPT-4o, Gemini 2.0, local via Ollama

---

### GitHub Copilot
**Best for**: IDE inline suggestions, PR reviews, code chat.

```bash
# VS Code — install extension
code --install-extension GitHub.copilot
code --install-extension GitHub.copilot-chat

# CLI
gh extension install github/gh-copilot
gh copilot suggest "delete all docker volumes"
gh copilot explain "git rebase -i HEAD~3"

# Authenticate
gh auth login
```

---

### Aider
**Best for**: Git-aware AI pair programmer in terminal.

```bash
# Install
pip install aider-install
aider-install

# OR
pip install aider-chat

# Run with Claude
aider --model claude-opus-4-6

# Run with GPT-4o
aider --model gpt-4o

# Auto-commit mode
aider --auto-commits

# Watch mode (accepts prompts from .aider-prompts file)
aider --watch-files
```

**Config** (`.aider.conf.yml`):
```yaml
model: claude-sonnet-4-6
auto-commits: true
dark-mode: true
pretty: true
stream: true
```

---

### Continue.dev
**Best for**: Open-source Copilot alternative, runs local models.

```bash
# VS Code extension
code --install-extension Continue.continue

# JetBrains plugin available via marketplace
```

**Config** (`~/.continue/config.json`):
```json
{
  "models": [
    {
      "title": "Claude Sonnet",
      "provider": "anthropic",
      "model": "claude-sonnet-4-6",
      "apiKey": "sk-ant-..."
    },
    {
      "title": "Ollama Llama 3.3",
      "provider": "ollama",
      "model": "llama3.3:70b"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Qwen2.5-Coder",
    "provider": "ollama",
    "model": "qwen2.5-coder:7b"
  }
}
```

---

### Windsurf (Codeium)
**Best for**: Agentic IDE with Cascade — multi-step task execution.

```bash
# Install from: https://codeium.com/windsurf
# macOS
brew install --cask windsurf
```

---

### Zed Editor
**Best for**: Fast Rust-based editor with native AI assistant.

```bash
brew install zed

# AI via settings.json
# Supports: Anthropic, GitHub Copilot, Ollama
```

---

## 2. Local LLM Runners

### Ollama — Recommended for Local
**Best for**: Running open-source LLMs locally with simple CLI.

```bash
# Install
brew install ollama        # macOS
curl -fsSL https://ollama.com/install.sh | sh  # Linux

# Start server (auto-starts on macOS)
ollama serve

# Pull and run models
ollama pull llama3.3:70b
ollama pull qwen2.5-coder:7b
ollama pull phi4:14b
ollama pull mistral-nemo:12b
ollama pull deepseek-r1:14b
ollama pull nomic-embed-text      # for RAG embeddings

# Run model
ollama run llama3.3:70b

# List local models
ollama list

# API (OpenAI-compatible)
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.3:70b",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

**Top models to run locally (April 2026)**:

| Model | Size | Best For |
|---|---|---|
| `llama3.3:70b` | 40GB | General purpose, best open model |
| `qwen2.5-coder:7b` | 4.7GB | Code completion, fast |
| `qwen2.5-coder:32b` | 19GB | Code, high quality |
| `deepseek-r1:14b` | 9GB | Reasoning tasks |
| `mistral-nemo:12b` | 7GB | Fast general purpose |
| `phi4:14b` | 9GB | Microsoft, efficient |
| `gemma3:27b` | 17GB | Google, multimodal |
| `nomic-embed-text` | 274MB | Embeddings for RAG |

---

### LM Studio
**Best for**: GUI for running local GGUF models, OpenAI-compatible server.

```bash
# Install from: https://lmstudio.ai
brew install --cask lm-studio

# Start local server from GUI or CLI
~/.lmstudio/bin/lms server start

# OpenAI-compatible endpoint
# http://localhost:1234/v1
```

---

### Jan
**Best for**: Privacy-first local AI chat, desktop app.

```bash
# Install from: https://jan.ai
brew install --cask jan
```

---

### Open WebUI
**Best for**: Web UI for Ollama and OpenAI, multi-user, RAG built-in.

```bash
# Docker (connects to Ollama on host)
docker run -d \
  -p 3000:8080 \
  -v open-webui:/app/backend/data \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  ghcr.io/open-webui/open-webui:main

# With bundled Ollama (GPU)
docker run -d \
  -p 3000:8080 \
  --gpus all \
  -v ollama:/root/.ollama \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:ollama
```

Access at `http://localhost:3000`

---

### AnythingLLM
**Best for**: Local RAG, multi-user workspace, local AI without cloud.

```bash
# Docker
docker pull mintplexlabs/anythingllm
docker run -d \
  -p 3001:3001 \
  -v ~/.anythingllm:/app/server/storage \
  mintplexlabs/anythingllm
```

---

## 3. AI Agent Frameworks

### LangChain / LangGraph
**Best for**: Building LLM chains and stateful agent graphs (Python & JS).

```bash
pip install langchain langgraph langchain-anthropic langchain-openai

# TypeScript
npm install langchain @langchain/anthropic @langchain/openai langgraph
```

**Python quickstart**:
```python
from langchain_anthropic import ChatAnthropic
from langgraph.graph import StateGraph, END

llm = ChatAnthropic(model="claude-sonnet-4-6")
response = llm.invoke("Explain LangGraph in one sentence")
```

---

### LlamaIndex
**Best for**: RAG pipelines, document ingestion, structured queries.

```bash
pip install llama-index llama-index-llms-anthropic llama-index-embeddings-ollama
```

```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader
from llama_index.llms.anthropic import Anthropic

llm = Anthropic(model="claude-sonnet-4-6")
docs = SimpleDirectoryReader("./data").load_data()
index = VectorStoreIndex.from_documents(docs)
query_engine = index.as_query_engine(llm=llm)
response = query_engine.query("What are the key topics?")
```

---

### CrewAI
**Best for**: Multi-agent teams with roles, tasks, and workflows.

```bash
pip install crewai crewai-tools
```

```python
from crewai import Agent, Task, Crew

researcher = Agent(
    role="Research Analyst",
    goal="Find the latest AI news",
    backstory="Expert in AI research",
    llm="claude-sonnet-4-6"
)

task = Task(
    description="Research top AI tools in 2026",
    agent=researcher,
    expected_output="Bullet-point list of tools"
)

crew = Crew(agents=[researcher], tasks=[task])
result = crew.kickoff()
```

---

### AutoGen (Microsoft)
**Best for**: Multi-agent conversations, code execution, human-in-loop.

```bash
pip install pyautogen autogen-agentchat autogen-ext
```

```python
from autogen import AssistantAgent, UserProxyAgent

assistant = AssistantAgent("assistant", llm_config={"model": "claude-sonnet-4-6"})
user = UserProxyAgent("user", human_input_mode="NEVER", max_consecutive_auto_reply=5)
user.initiate_chat(assistant, message="Write a Python web scraper")
```

---

### Claude Agent SDK (Anthropic)
**Best for**: Building production AI agents with Claude, tool use, streaming.

```bash
pip install anthropic
npm install @anthropic-ai/sdk
```

```python
import anthropic

client = anthropic.Anthropic()

# Tool use
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    tools=[{
        "name": "web_search",
        "description": "Search the web",
        "input_schema": {
            "type": "object",
            "properties": {"query": {"type": "string"}},
            "required": ["query"]
        }
    }],
    messages=[{"role": "user", "content": "Search for latest AI news"}]
)

# Extended thinking (Opus 4.6)
response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=16000,
    thinking={"type": "enabled", "budget_tokens": 10000},
    messages=[{"role": "user", "content": "Solve this complex problem..."}]
)
```

---

### DSPy
**Best for**: Programmatic prompt optimization, compiling prompts.

```bash
pip install dspy-ai
```

---

### Pydantic AI
**Best for**: Type-safe AI agents in Python, production-grade.

```bash
pip install pydantic-ai
```

```python
from pydantic_ai import Agent
from pydantic import BaseModel

class Result(BaseModel):
    answer: str
    confidence: float

agent = Agent("claude-sonnet-4-6", result_type=Result)
result = agent.run_sync("What is the capital of France?")
print(result.data.answer)
```

---

### Mastra (TypeScript)
**Best for**: TypeScript-first agent framework, workflows, memory.

```bash
npm install @mastra/core @mastra/memory
```

---

### Agno (formerly Phidata)
**Best for**: Building AI applications with memory, knowledge, tools.

```bash
pip install agno
```

---

## 4. LLM APIs & SDKs

### Anthropic (Claude)
```bash
pip install anthropic
export ANTHROPIC_API_KEY=sk-ant-...

# Models (April 2026)
# claude-opus-4-6       — most capable, extended thinking
# claude-sonnet-4-6     — balanced speed/intelligence
# claude-haiku-4-5-20251001 — fastest, most affordable
```

### OpenAI
```bash
pip install openai
export OPENAI_API_KEY=sk-...

# Models
# gpt-4o               — multimodal, fast
# o3                   — reasoning
# o4-mini              — affordable reasoning
```

### Google Gemini
```bash
pip install google-generativeai
export GOOGLE_API_KEY=...

# Models
# gemini-2.0-flash     — fast multimodal
# gemini-2.5-pro       — most capable
```

### Groq (Ultra-fast inference)
```bash
pip install groq
export GROQ_API_KEY=...

# Runs: llama3.3-70b, mixtral, gemma2 at 600+ tokens/sec
```

### Together AI
```bash
pip install together
# Open-source models at scale
```

### Replicate
```bash
pip install replicate
# Run any open-source model via API
```

### LiteLLM — Universal LLM Gateway
```bash
pip install litellm

# Use any provider with one interface
import litellm
response = litellm.completion(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "Hello"}]
)
# Supports: Anthropic, OpenAI, Gemini, Groq, Ollama, 100+ providers
```

---

## 5. RAG & Knowledge Tools

### Chroma (Local Vector DB)
```bash
pip install chromadb

# Embedded (no server)
import chromadb
client = chromadb.Client()
collection = client.create_collection("docs")
collection.add(documents=["text1", "text2"], ids=["1","2"])
results = collection.query(query_texts=["search query"], n_results=2)
```

### Qdrant
```bash
docker run -p 6333:6333 qdrant/qdrant
pip install qdrant-client
```

### Weaviate
```bash
docker run -p 8080:8080 semitechnologies/weaviate
pip install weaviate-client
```

### pgvector (Postgres)
```bash
docker run -p 5432:5432 -e POSTGRES_PASSWORD=pass pgvector/pgvector:pg16
pip install pgvector psycopg2-binary
```

### Pinecone (Cloud)
```bash
pip install pinecone-client
```

---

## 6. MCP Servers

MCP (Model Context Protocol) connects Claude Code to external tools.

### Install popular MCP servers

```bash
# GitHub — code, PRs, issues
claude mcp add --transport http github https://api.githubcopilot.com/mcp/

# Sentry — error monitoring
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# Notion — docs and wikis
claude mcp add --transport http notion https://mcp.notion.com/mcp

# Slack — team communication
claude mcp add --transport http slack https://mcp.slack.com/mcp

# Jira — project management
claude mcp add --transport http jira https://mcp.atlassian.com/mcp

# PostgreSQL — database queries
claude mcp add --transport stdio postgres -- \
  npx -y @bytebase/dbhub --dsn "postgresql://user:pass@host:5432/db"

# Filesystem — local file access
claude mcp add --transport stdio filesystem -- \
  npx -y @modelcontextprotocol/server-filesystem /path/to/dir

# Browser — web automation
claude mcp add --transport stdio playwright -- \
  npx -y @playwright/mcp@latest

# Fetch — web content fetching
claude mcp add --transport stdio fetch -- \
  npx -y @modelcontextprotocol/server-fetch

# Memory — persistent key-value store
claude mcp add --transport stdio memory -- \
  npx -y @modelcontextprotocol/server-memory
```

### List and manage servers
```bash
claude mcp list
claude mcp get github
claude mcp remove github
# In Claude Code session:
/mcp
```

---

## 7. AI Image & Media Tools

### ComfyUI (Local Stable Diffusion)
```bash
git clone https://github.com/comfyanonymous/ComfyUI
cd ComfyUI
pip install -r requirements.txt
python main.py
# Access at http://localhost:8188
```

### Automatic1111 WebUI
```bash
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui
cd stable-diffusion-webui
./webui.sh    # macOS/Linux
```

### Replicate API (Cloud image gen)
```bash
pip install replicate
import replicate
output = replicate.run("black-forest-labs/flux-1.1-pro", input={"prompt": "..."})
```

---

## 8. Observability & Evaluation

### LangSmith (LangChain tracing)
```bash
pip install langsmith
export LANGCHAIN_TRACING_V2=true
export LANGCHAIN_API_KEY=...
```

### Langfuse (Open-source LLM observability)
```bash
# Docker
docker compose up -d
pip install langfuse

from langfuse import Langfuse
langfuse = Langfuse(public_key="...", secret_key="...", host="...")
```

### Weights & Biases
```bash
pip install wandb
wandb login
```

### Promptfoo (LLM testing)
```bash
npm install -g promptfoo
promptfoo init
promptfoo eval
```

---

## 9. Local Setup Configs

### Environment Variables (`.env`)
```bash
# Core AI APIs
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GOOGLE_API_KEY=...
GROQ_API_KEY=...
TOGETHER_API_KEY=...

# Observability
LANGCHAIN_TRACING_V2=true
LANGCHAIN_API_KEY=...
LANGCHAIN_PROJECT=my-project

# Local inference
OLLAMA_BASE_URL=http://localhost:11434

# Vector DBs
QDRANT_URL=http://localhost:6333
CHROMA_HOST=localhost
CHROMA_PORT=8000
```

### Python virtual environment setup
```bash
python -m venv .venv
source .venv/bin/activate    # macOS/Linux
.venv\Scripts\activate       # Windows

pip install anthropic openai langchain langgraph llama-index crewai pydantic-ai litellm chromadb qdrant-client
```

### Docker Compose — Local AI Stack
```yaml
# docker-compose.ai.yml
version: "3.9"
services:
  ollama:
    image: ollama/ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    volumes:
      - open-webui:/app/backend/data
    depends_on:
      - ollama

  qdrant:
    image: qdrant/qdrant
    ports:
      - "6333:6333"
    volumes:
      - qdrant:/qdrant/storage

  langfuse:
    image: langfuse/langfuse
    ports:
      - "3001:3000"
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@postgres:5432/langfuse
      - NEXTAUTH_SECRET=secret
      - NEXTAUTH_URL=http://localhost:3001

volumes:
  ollama:
  open-webui:
  qdrant:
  langfuse:
```

```bash
docker compose -f docker-compose.ai.yml up -d

# Pull a model after Ollama starts
docker exec -it <ollama-container-id> ollama pull llama3.3:70b
```

### macOS AI Dev Setup Script
```bash
#!/bin/bash
# Install AI dev essentials

# Ollama
brew install ollama
ollama pull llama3.3:70b
ollama pull qwen2.5-coder:7b
ollama pull nomic-embed-text

# Claude Code
npm install -g @anthropic-ai/claude-code

# Python AI stack
python -m venv ~/ai-venv
source ~/ai-venv/bin/activate
pip install anthropic openai langchain langgraph llama-index \
            crewai pydantic-ai litellm chromadb qdrant-client \
            aider-chat promptfoo

# Node AI tools
npm install -g promptfoo @anthropic-ai/claude-code

echo "AI stack ready!"
```

---

## Quick Reference — Model Selection Guide

| Use Case | Recommended Model | Why |
|---|---|---|
| Complex reasoning | `claude-opus-4-6` | Extended thinking, best accuracy |
| General coding | `claude-sonnet-4-6` | Fast + smart |
| High-volume / cheap | `claude-haiku-4-5` | Fastest, lowest cost |
| Local coding | `qwen2.5-coder:7b` via Ollama | Privacy, offline |
| Local general | `llama3.3:70b` via Ollama | Best open-source |
| Ultra-fast inference | Any model via Groq | 600+ tokens/sec |
| Reasoning tasks | `o3` / `deepseek-r1` | Chain-of-thought |
| Multimodal | `gemini-2.5-pro` / `gpt-4o` | Image + text |
