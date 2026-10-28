# LLM-Ops — Managing LLMs in Production

> Tools and patterns for deploying, monitoring, evaluating, and optimizing LLMs in production systems.

## What is LLM-Ops?

LLM-Ops extends MLOps principles to large language models. It covers:
- **Model serving** — Efficiently serve models with low latency
- **Prompt management** — Version, test, and deploy prompts like code
- **Evaluation** — Automated testing of LLM outputs for quality/safety
- **Observability** — Trace every LLM call, monitor costs, detect degradation
- **Fine-tuning** — Customize models on your domain data
- **RAG pipelines** — Build and maintain retrieval-augmented generation systems

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  Application Layer                    │
│         (Your App / API / Agent Workflows)            │
└──────────────────┬───────────────────────────────────┘
                   │
┌──────────────────▼───────────────────────────────────┐
│               LLM Gateway / Router                    │
│    (LiteLLM / PortKey / OpenRouter / Custom)         │
│  - Model routing    - Cost tracking    - Fallbacks   │
└──────────────────┬───────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
┌───────▼───────┐    ┌────────▼────────┐
│  Cloud APIs   │    │  Local Models   │
│  Claude 4.6   │    │  Ollama:        │
│  GPT-4o       │    │  qwen2.5-coder  │
│  Gemini 2.0   │    │  llama3.3:70b   │
└───────────────┘    └─────────────────┘
        │                     │
┌───────▼─────────────────────▼────────┐
│           Observability Layer         │
│   LangSmith / Langfuse / Helicone    │
│   - Traces  - Evals  - Cost tracking │
└──────────────────────────────────────┘
```

## Tools Coverage

| Category | Tools |
|----------|-------|
| **LLM Gateway** | LiteLLM, PortKey, OpenRouter |
| **Prompt Management** | Langfuse, PromptLayer, LangChain Hub |
| **Observability** | LangSmith, Langfuse, Helicone, OpenLLMetry |
| **Local Inference** | Ollama, vLLM, llama.cpp, LM Studio |
| **RAG** | Chroma, Qdrant, pgvector, LlamaIndex |
| **Evaluation** | RAGAS, TruLens, DeepEval, PromptBench |
| **Fine-tuning** | Unsloth, Axolotl, Modal, Together AI |
| **Vector Search** | Pinecone, Weaviate, Milvus |

## Quick Start

### 1. LiteLLM Gateway (Route between any LLM)

```bash
# Install
pip install litellm

# Start proxy server (replaces all models with one unified API)
litellm --model claude-sonnet-4-6 --port 8000

# Or with config
litellm --config configs/litellm_config.yaml

# Now use OpenAI SDK pointing to localhost
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4-6", "messages": [{"role": "user", "content": "Hello"}]}'
```

### 2. Langfuse (Prompt observability & tracing)

```bash
# Self-host with Docker
docker compose up -f configs/langfuse-docker-compose.yaml

# Or use cloud: https://cloud.langfuse.com

# Instrument your Python app
pip install langfuse
```

```python
from langfuse.decorators import observe, langfuse_context

@observe()
def generate_response(prompt: str) -> str:
    # Every call is automatically traced
    response = anthropic_client.messages.create(...)
    return response.content[0].text
```

### 3. Ollama — Run LLMs Locally

```bash
# Install
brew install ollama      # macOS
curl -fsSL https://ollama.com/install.sh | sh  # Linux

# Pull models
ollama pull llama3.3:70b         # Meta's best open model
ollama pull qwen2.5-coder:32b   # Best coding model
ollama pull phi4:14b             # Microsoft, fast + smart
ollama pull deepseek-r1:70b     # Best reasoning model
ollama pull nomic-embed-text    # For RAG embeddings

# Run model
ollama run qwen2.5-coder:32b

# Use OpenAI-compatible API
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen2.5-coder:32b", "messages": [{"role": "user", "content": "Write a Python hello world"}]}'

# List running models
ollama ps

# Model info
ollama show llama3.3:70b
```

### 4. vLLM — High-throughput LLM serving

```bash
# Install (GPU required)
pip install vllm

# Serve a model
python -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen2.5-Coder-32B-Instruct \
  --tensor-parallel-size 2 \
  --max-model-len 32768 \
  --port 8000

# Docker
docker run --runtime nvidia --gpus all \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -p 8000:8000 \
  vllm/vllm-openai:latest \
  --model Qwen/Qwen2.5-Coder-32B-Instruct
```

### 5. RAG Pipeline with pgvector

```bash
# Enable pgvector in PostgreSQL
psql -c "CREATE EXTENSION vector;"

# Install dependencies
pip install pgvector psycopg2 anthropic
```

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/model_benchmark.py` | Benchmark latency/cost/quality across models |
| `scripts/prompt_manager.py` | Version and A/B test prompts |
| `scripts/rag_pipeline.py` | Build a RAG pipeline from documents |
| `scripts/eval_pipeline.py` | Automated LLM output evaluation |
| `scripts/cost_tracker.py` | Track and alert on LLM spend |

## Prompt Engineering Best Practices

```python
# System prompt template for consistent outputs
SYSTEM_TEMPLATE = """You are {role}.

## Context
{context}

## Task
{task}

## Output Format
{format_instructions}

## Constraints
- {constraint_1}
- {constraint_2}

Always {positive_instruction}. Never {negative_instruction}."""

# Use structured outputs (JSON mode)
message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system="Always respond with valid JSON only.",
    messages=[{"role": "user", "content": prompt}],
)
```

## Cost Optimization

```python
# Route based on task complexity
def smart_route(prompt: str, context_length: int) -> str:
    if context_length > 100000:
        return "claude-sonnet-4-6"      # Large context
    elif is_simple_task(prompt):
        return "claude-haiku-4-5-20251001"  # Fast + cheap
    elif needs_reasoning(prompt):
        return "claude-opus-4-6"        # Most capable
    else:
        return "claude-sonnet-4-6"      # Default balanced
```

## Evaluation Framework

```bash
# Run evals against your prompts
python scripts/eval_pipeline.py \
  --prompt prompts/code_reviewer_v2.yaml \
  --dataset datasets/code_review_test.jsonl \
  --metrics accuracy,hallucination,latency \
  --compare-to prompts/code_reviewer_v1.yaml
```

## Model Selection Guide (2026)

| Use Case | Best Model | Notes |
|----------|-----------|-------|
| Complex reasoning | `claude-opus-4-6` | Extended thinking for hard problems |
| Code generation | `claude-sonnet-4-6` | Best code quality |
| Fast responses | `claude-haiku-4-5` | <1s, good for real-time |
| Privacy-sensitive | `ollama/qwen2.5-coder` | Data never leaves machine |
| Long documents | `claude-sonnet-4-6` | 200k context |
| Embeddings | `nomic-embed-text` | Free via Ollama |
| Structured output | `claude-sonnet-4-6` | Reliable JSON |
