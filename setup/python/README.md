# Python Setup — pyenv, uv, Virtual Environments

Complete Python environment setup for developers.
Updated: April 2026.

---

## Install Python via pyenv (Recommended)

pyenv manages multiple Python versions on one machine.

```bash
# macOS
brew install pyenv

# Linux
curl https://pyenv.run | bash

# Add to ~/.zshrc (or ~/.bashrc)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Reload shell
source ~/.zshrc
```

### Managing Python versions

```bash
# List available versions
pyenv install --list
pyenv install --list | grep "3.13"

# Install versions
pyenv install 3.13.2
pyenv install 3.12.9
pyenv install 3.11.11

# Set versions
pyenv global 3.13.2            # System-wide default
pyenv local 3.12.9             # Project-specific (.python-version file)
pyenv shell 3.11.11            # Current shell only

# List installed
pyenv versions

# Show active version
pyenv version
python --version
```

---

## uv — Ultra-fast Python Package Manager

uv (by Astral) replaces pip, pip-tools, virtualenv, and more. 10-100x faster than pip.

```bash
# Install
curl -LsSf https://astral.sh/uv/install.sh | sh
# or
brew install uv

uv --version
```

### Virtual environments with uv

```bash
# Create venv
uv venv                        # creates .venv in current dir
uv venv --python 3.13          # specific Python version
uv venv myenv                  # named venv

# Activate
source .venv/bin/activate      # macOS/Linux
.venv\Scripts\activate         # Windows

# Deactivate
deactivate
```

### Installing packages with uv

```bash
# Install packages
uv pip install fastapi
uv pip install "fastapi[all]"           # with extras
uv pip install -r requirements.txt
uv pip install -e .                     # editable install

# Install from lockfile
uv pip sync requirements.txt

# Remove
uv pip uninstall fastapi

# List installed
uv pip list
uv pip show fastapi

# Generate requirements
uv pip freeze > requirements.txt
```

### uv project management (pyproject.toml)

```bash
# Create new project
uv init my-project
cd my-project

# Add dependencies
uv add fastapi
uv add "sqlalchemy>=2.0"
uv add --dev pytest ruff mypy

# Remove
uv remove fastapi

# Run with uv (auto-manages venv)
uv run python main.py
uv run pytest
uv run -- uvicorn app.main:app --reload

# Lock dependencies
uv lock

# Sync environment from lockfile
uv sync
uv sync --only-dev
```

### uv tool — global CLI tools

```bash
# Install CLI tools in isolated envs (like pipx)
uv tool install ruff
uv tool install black
uv tool install mypy
uv tool install httpie
uv tool install aider-chat

# Run without installing
uv tool run ruff check .
uvx ruff check .               # shorthand

# Update all tools
uv tool upgrade --all

# List tools
uv tool list
```

---

## pip & pip-tools (Traditional)

```bash
# pip basics
pip install package
pip install "package>=2.0,<3.0"
pip install -r requirements.txt
pip install -e .               # editable
pip uninstall package
pip list
pip show package
pip freeze > requirements.txt

# Upgrade pip itself
pip install --upgrade pip

# pip-tools — deterministic dependency resolution
pip install pip-tools

# requirements.in (top-level deps only)
# requirements.txt (compiled, pinned)

pip-compile requirements.in    # generate pinned requirements.txt
pip-sync requirements.txt      # install exact versions
pip-compile --upgrade          # upgrade all packages
```

---

## Virtual Environments

### venv (stdlib)

```bash
# Create
python -m venv .venv
python3.13 -m venv .venv      # specific version

# Activate
source .venv/bin/activate      # macOS/Linux
.venv\Scripts\activate.ps1     # Windows PowerShell

# Deactivate
deactivate

# Delete and recreate
rm -rf .venv && python -m venv .venv
```

### Auto-activate with direnv

```bash
# .envrc in project root
layout python3                 # creates + activates venv automatically
# or with uv:
layout uv
```

---

## pyproject.toml — Modern Python Project

```toml
[project]
name = "my-project"
version = "0.1.0"
description = "My Python project"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.32.0",
    "sqlalchemy>=2.0.36",
    "pydantic>=2.10.0",
    "anthropic>=0.40.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.3.0",
    "pytest-asyncio>=0.24.0",
    "pytest-cov>=6.0.0",
    "ruff>=0.8.0",
    "mypy>=1.13.0",
    "httpx>=0.28.0",
]

[project.scripts]
serve = "app.main:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
line-length = 100
target-version = "py312"
extend-select = ["I", "N", "UP", "ANN", "S", "B", "C4", "ERA"]
ignore = ["ANN101", "ANN102"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.mypy]
python_version = "3.13"
strict = true
ignore_missing_imports = true

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
addopts = "-v --cov=app --cov-report=term-missing"

[tool.coverage.report]
exclude_lines = ["pragma: no cover", "if TYPE_CHECKING:"]
```

---

## Code Quality Tools

### Ruff (Linter + Formatter — replaces Black, isort, flake8)

```bash
uv tool install ruff
# or
pip install ruff

# Check
ruff check .
ruff check . --fix             # auto-fix

# Format (replaces Black)
ruff format .
ruff format --check .          # check only

# Watch mode
ruff check . --watch
```

### mypy (Static type checking)

```bash
pip install mypy

mypy app/
mypy --strict app/             # strict mode
mypy --ignore-missing-imports app/
```

### pre-commit

```bash
pip install pre-commit

# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.13.0
    hooks:
      - id: mypy
        additional_dependencies: [types-all]

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-toml
      - id: debug-statements

pre-commit install
pre-commit run --all-files
```

---

## Testing

### pytest

```bash
pip install pytest pytest-asyncio pytest-cov httpx

# Run tests
pytest                             # all tests
pytest tests/test_users.py        # single file
pytest -k "test_create"           # by name pattern
pytest -v                         # verbose
pytest --cov=app --cov-report=html # with coverage

# pytest marks
pytest -m "unit"                  # run only unit tests
pytest -m "not slow"              # exclude slow tests
```

**`tests/conftest.py`**:

```python
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.fixture
def anyio_backend():
    return "asyncio"
```

---

## Packaging & Publishing

```bash
# Build
uv build
# or
pip install build && python -m build

# Publish to PyPI
pip install twine
twine upload dist/*

# Publish with uv
uv publish
```

---

## Python Version Quick Reference

| Version | Status | Notes |
|---|---|---|
| 3.13 | Active | Latest, `t` free-threading builds |
| 3.12 | Active | `@override`, `f-string` improvements |
| 3.11 | Active | 10-60% faster than 3.10 |
| 3.10 | Security only | `match` statement |
| 3.9 | End of life | EOL Oct 2025 |

**Always use 3.12+ for new projects.**

---

## Common Development Patterns

### FastAPI project setup

```bash
uv init my-api
cd my-api
uv add fastapi "uvicorn[standard]" sqlalchemy alembic pydantic-settings
uv add --dev pytest pytest-asyncio httpx ruff mypy
uv run uvicorn app.main:app --reload
```

### AI/ML project setup

```bash
uv init my-ml-project
cd my-ml-project
uv add anthropic langchain langgraph llama-index chromadb qdrant-client
uv add torch torchvision          # add --index for CUDA
uv add --dev jupyter notebook ruff
uv run jupyter notebook
```

### Data science project setup

```bash
uv init analysis
cd analysis
uv add pandas polars numpy matplotlib seaborn scikit-learn
uv add --dev jupyter notebook ipykernel
uv run jupyter notebook
```
