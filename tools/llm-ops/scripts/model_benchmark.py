#!/usr/bin/env python3
"""
LLM Model Benchmarker — Compare latency, cost, and quality across models.

Tests a set of prompts against multiple LLM providers and outputs a
comparison table showing response quality, tokens/sec, and cost.

Usage:
    python model_benchmark.py --models claude-sonnet-4-6,claude-haiku-4-5-20251001 --prompts default
    python model_benchmark.py --models all --prompts configs/custom_prompts.yaml

Dependencies:
    pip install anthropic openai litellm tabulate python-dotenv
"""

import os
import time
import json
import statistics
from dataclasses import dataclass, field
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

try:
    import anthropic
    from tabulate import tabulate
except ImportError:
    print("pip install anthropic tabulate python-dotenv")
    raise

# ─────────────────────────────
# DEFAULT TEST PROMPTS
# ─────────────────────────────
DEFAULT_PROMPTS = [
    {
        "name": "code_generation",
        "category": "coding",
        "prompt": "Write a Python function that implements a binary search tree with insert, search, and delete operations. Include type hints.",
        "expected_keywords": ["class", "def insert", "def search", "def delete"],
    },
    {
        "name": "reasoning",
        "category": "reasoning",
        "prompt": "A company has 3 servers. Each server processes 100 requests/second. If traffic doubles every 6 months and current traffic is 150 req/s, how many months until they need a 4th server?",
        "expected_keywords": ["6", "months"],
    },
    {
        "name": "summarization",
        "category": "language",
        "prompt": "Summarize the key differences between TCP and UDP protocols in 3 bullet points for a junior developer.",
        "expected_keywords": ["reliable", "unreliable", "connection"],
    },
    {
        "name": "json_output",
        "category": "structured",
        "prompt": 'Return a JSON object with fields: name (string), age (number), skills (array of 3 strings). Use fictional data. Return ONLY the JSON, no other text.',
        "expected_json": True,
    },
]

MODELS_TO_TEST = {
    "claude-sonnet-4-6": {"provider": "anthropic", "input_cost_per_1m": 3.0, "output_cost_per_1m": 15.0},
    "claude-haiku-4-5-20251001": {"provider": "anthropic", "input_cost_per_1m": 0.80, "output_cost_per_1m": 4.0},
    "claude-opus-4-6": {"provider": "anthropic", "input_cost_per_1m": 15.0, "output_cost_per_1m": 75.0},
}


@dataclass
class BenchmarkResult:
    model: str
    prompt_name: str
    latency_ms: float
    input_tokens: int
    output_tokens: int
    cost_usd: float
    quality_score: float  # 0-1
    response_preview: str
    error: Optional[str] = None


@dataclass
class ModelSummary:
    model: str
    avg_latency_ms: float
    p95_latency_ms: float
    total_cost_usd: float
    avg_quality: float
    tokens_per_second: float
    results: list[BenchmarkResult] = field(default_factory=list)


def call_anthropic(model: str, prompt: str) -> tuple[str, int, int, float]:
    """Call Anthropic API and return (response, input_tokens, output_tokens, latency_ms)."""
    client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    start = time.time()
    message = client.messages.create(
        model=model,
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    latency_ms = (time.time() - start) * 1000
    response = message.content[0].text
    return response, message.usage.input_tokens, message.usage.output_tokens, latency_ms


def score_response(response: str, prompt_config: dict) -> float:
    """Score response quality based on expected keywords/format."""
    score = 0.5  # Base score for responding at all

    # Check for expected keywords
    if "expected_keywords" in prompt_config:
        keywords = prompt_config["expected_keywords"]
        found = sum(1 for kw in keywords if kw.lower() in response.lower())
        score = 0.5 + (0.5 * found / len(keywords))

    # Check for valid JSON
    elif prompt_config.get("expected_json"):
        try:
            json.loads(response.strip())
            score = 1.0
        except json.JSONDecodeError:
            score = 0.1

    # Penalize very short responses
    if len(response) < 50:
        score *= 0.5

    return min(1.0, score)


def calculate_cost(model: str, input_tokens: int, output_tokens: int) -> float:
    """Calculate cost in USD for a given model and token count."""
    model_info = MODELS_TO_TEST.get(model, {})
    input_cost = (input_tokens / 1_000_000) * model_info.get("input_cost_per_1m", 0)
    output_cost = (output_tokens / 1_000_000) * model_info.get("output_cost_per_1m", 0)
    return input_cost + output_cost


def benchmark_model(model: str, prompts: list[dict], runs: int = 2) -> ModelSummary:
    """Run all prompts against a model and collect results."""
    results = []
    provider = MODELS_TO_TEST.get(model, {}).get("provider", "anthropic")

    for prompt_config in prompts:
        latencies = []
        for run in range(runs):
            try:
                if provider == "anthropic":
                    response, input_tok, output_tok, latency_ms = call_anthropic(
                        model, prompt_config["prompt"]
                    )
                else:
                    raise NotImplementedError(f"Provider {provider} not implemented")

                cost = calculate_cost(model, input_tok, output_tok)
                quality = score_response(response, prompt_config)
                latencies.append(latency_ms)

                result = BenchmarkResult(
                    model=model,
                    prompt_name=prompt_config["name"],
                    latency_ms=latency_ms,
                    input_tokens=input_tok,
                    output_tokens=output_tok,
                    cost_usd=cost,
                    quality_score=quality,
                    response_preview=response[:100] + "...",
                )
                results.append(result)
                time.sleep(0.5)  # Rate limiting

            except Exception as e:
                results.append(
                    BenchmarkResult(
                        model=model,
                        prompt_name=prompt_config["name"],
                        latency_ms=0,
                        input_tokens=0,
                        output_tokens=0,
                        cost_usd=0,
                        quality_score=0,
                        response_preview="",
                        error=str(e),
                    )
                )

    # Calculate summary stats
    valid = [r for r in results if not r.error]
    if not valid:
        return ModelSummary(model=model, avg_latency_ms=0, p95_latency_ms=0,
                           total_cost_usd=0, avg_quality=0, tokens_per_second=0, results=results)

    latencies = [r.latency_ms for r in valid]
    latencies.sort()
    total_tokens = sum(r.output_tokens for r in valid)
    total_latency_s = sum(r.latency_ms for r in valid) / 1000

    return ModelSummary(
        model=model,
        avg_latency_ms=statistics.mean(latencies),
        p95_latency_ms=latencies[int(len(latencies) * 0.95)] if len(latencies) > 1 else latencies[0],
        total_cost_usd=sum(r.cost_usd for r in valid),
        avg_quality=statistics.mean(r.quality_score for r in valid),
        tokens_per_second=total_tokens / max(total_latency_s, 0.001),
        results=results,
    )


def print_results(summaries: list[ModelSummary]):
    """Print comparison table."""
    print("\n" + "=" * 80)
    print("LLM BENCHMARK RESULTS")
    print("=" * 80)

    # Summary table
    headers = ["Model", "Avg Latency", "P95 Latency", "Tok/sec", "Quality", "Total Cost"]
    rows = []
    for s in sorted(summaries, key=lambda x: x.avg_quality, reverse=True):
        rows.append([
            s.model,
            f"{s.avg_latency_ms:.0f}ms",
            f"{s.p95_latency_ms:.0f}ms",
            f"{s.tokens_per_second:.0f}",
            f"{s.avg_quality:.1%}",
            f"${s.total_cost_usd:.4f}",
        ])

    print("\nSUMMARY:")
    print(tabulate(rows, headers=headers, tablefmt="rounded_outline"))

    # Per-prompt breakdown
    print("\nPER-PROMPT BREAKDOWN:")
    prompt_names = list({r.prompt_name for s in summaries for r in s.results})
    for prompt_name in prompt_names:
        print(f"\n  {prompt_name}:")
        prompt_rows = []
        for s in summaries:
            results = [r for r in s.results if r.prompt_name == prompt_name and not r.error]
            if results:
                avg_latency = statistics.mean(r.latency_ms for r in results)
                avg_quality = statistics.mean(r.quality_score for r in results)
                prompt_rows.append([s.model, f"{avg_latency:.0f}ms", f"{avg_quality:.1%}"])
        print(tabulate(prompt_rows, headers=["Model", "Latency", "Quality"], tablefmt="simple"))

    # Recommendation
    print("\nRECOMMENDATION:")
    best_quality = max(summaries, key=lambda x: x.avg_quality)
    best_value = max(summaries, key=lambda x: x.avg_quality / max(x.total_cost_usd, 0.0001))
    fastest = min(summaries, key=lambda x: x.avg_latency_ms)
    print(f"  Best quality:  {best_quality.model} ({best_quality.avg_quality:.1%})")
    print(f"  Best value:    {best_value.model}")
    print(f"  Fastest:       {fastest.model} ({fastest.avg_latency_ms:.0f}ms avg)")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="LLM model benchmarker")
    parser.add_argument(
        "--models",
        default="claude-sonnet-4-6,claude-haiku-4-5-20251001",
        help="Comma-separated list of models",
    )
    parser.add_argument("--runs", type=int, default=2, help="Runs per prompt")
    parser.add_argument("--output-json", help="Save results to JSON file")
    args = parser.parse_args()

    models = args.models.split(",") if args.models != "all" else list(MODELS_TO_TEST.keys())
    prompts = DEFAULT_PROMPTS

    print(f"Benchmarking {len(models)} models across {len(prompts)} prompts ({args.runs} runs each)...")
    print(f"Models: {', '.join(models)}")

    summaries = []
    for model in models:
        print(f"\nTesting {model}...")
        summary = benchmark_model(model, prompts, args.runs)
        summaries.append(summary)
        print(f"  Done: avg {summary.avg_latency_ms:.0f}ms, quality {summary.avg_quality:.1%}")

    print_results(summaries)

    if args.output_json:
        data = [
            {
                "model": s.model,
                "avg_latency_ms": s.avg_latency_ms,
                "p95_latency_ms": s.p95_latency_ms,
                "total_cost_usd": s.total_cost_usd,
                "avg_quality": s.avg_quality,
                "tokens_per_second": s.tokens_per_second,
            }
            for s in summaries
        ]
        with open(args.output_json, "w") as f:
            json.dump(data, f, indent=2)
        print(f"\nResults saved to {args.output_json}")


if __name__ == "__main__":
    main()
