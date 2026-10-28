.PHONY: help install lint test test-rabbitmq e2e scan check run token docker-build docker-run compose-up compose-down

UV_RUN := uv run --locked
IMAGE  := payments-api:dev
SECRET_DIR := .local-secrets

help: ## Show available commands
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

install: ## Install locked dependencies
	uv sync --locked

lint: ## Ruff lint + format check, strict mypy
	$(UV_RUN) ruff check .
	$(UV_RUN) ruff format --check .
	$(UV_RUN) mypy

test: ## Unit and integration tests with coverage gate
	$(UV_RUN) pytest --cov --cov-fail-under=90

test-rabbitmq: ## Integration tests against a real broker (starts one with Docker Compose)
	docker compose up -d --wait rabbitmq
	RABBITMQ_URL='amqp://payments:payments-local-only@localhost:5672/%2F' $(UV_RUN) pytest -m rabbitmq -v

e2e: ## E2E tests against BASE_URL (default: local run)
	BASE_URL=$${BASE_URL:-http://localhost:8000} JWT_SECRET=$$(cat $(SECRET_DIR)/jwt) $(UV_RUN) pytest tests/e2e -v

scan: ## Bandit, Semgrep, pip-audit, Checkov
	$(UV_RUN) bandit -q -r src -ll
	uvx semgrep@1.180.0 scan --config p/python --config p/owasp-top-ten --config p/secrets --metrics off --error src
	uv export --locked --no-dev --no-emit-project --no-header --quiet -o /tmp/payments-api-requirements.txt
	$(UV_RUN) pip-audit --disable-pip --strict -r /tmp/payments-api-requirements.txt
	uvx checkov@3.3.29 --compact --quiet --framework dockerfile -f Dockerfile
	uvx checkov@3.3.29 --compact --quiet --framework kubernetes -d deploy/k8s

check: lint test scan ## Everything CI runs before building the image

$(SECRET_DIR):
	@mkdir -p $(SECRET_DIR) && chmod 700 $(SECRET_DIR)
	@openssl rand -hex 32 > $(SECRET_DIR)/jwt
	@openssl rand -hex 32 > $(SECRET_DIR)/pan
	@echo 'amqp://payments:payments-local-only@rabbitmq:5672/%2F' > $(SECRET_DIR)/rabbitmq_url
	@echo "Generated throwaway secrets in $(SECRET_DIR)/"

run: $(SECRET_DIR) ## Run the API locally on :8000
	JWT_SECRET_FILE=$(SECRET_DIR)/jwt PAN_HMAC_KEY_FILE=$(SECRET_DIR)/pan \
	DATABASE_PATH=$(SECRET_DIR)/payments.db PYTHONPATH=src ENABLE_DOCS=true \
	$(UV_RUN) uvicorn --factory payments_api.main:create_app --port 8000 --no-server-header

token: $(SECRET_DIR) ## Print an access token with read and write scopes
	@JWT_SECRET_FILE=$(SECRET_DIR)/jwt PYTHONPATH=src $(UV_RUN) python -m payments_api.token_cli \
		--subject alice --scope transactions:read --scope transactions:write

docker-build: ## Build the container image
	docker build -t $(IMAGE) .

docker-run: $(SECRET_DIR) ## Run the image with the same hardening as CI
	docker run --rm -p 8000:8000 --read-only --tmpfs /tmp \
		--tmpfs /data:rw,uid=10001,gid=10001 --cap-drop ALL --security-opt no-new-privileges \
		-e JWT_SECRET="$$(cat $(SECRET_DIR)/jwt)" -e PAN_HMAC_KEY="$$(cat $(SECRET_DIR)/pan)" $(IMAGE)

compose-up: $(SECRET_DIR) ## Start API + RabbitMQ + risk monitor (http://localhost:8000)
	docker compose up -d --build --wait rabbitmq api
	docker compose up -d risk-monitor

compose-down: ## Stop the local stack
	docker compose down -v
