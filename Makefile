
.DEFAULT_GOAL := help

GO ?= go
COMPOSE ?= docker compose
ANSIBLE_PLAYBOOK ?= ansible-playbook
ANSIBLE_GALAXY ?= ansible-galaxy
CURL ?= curl

APP := http-server-projeto-korp
BIN_DIR := bin

INVENTORY := ansible/inventory/hosts.ini
PLAYBOOK := ansible/site.yml
REQUIREMENTS := ansible/requirements.yml

.PHONY: help fmt test vet check build up rebuild down restart ps logs validate ansible-deps ansible-check provision clean

help: ## Listar comandos disponíveis
	@awk 'BEGIN {FS = ":.*## "; printf "Comandos disponíveis:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

fmt: ## Formatar código Go
	$(GO) fmt ./...

test: ## Executar testes Go
	$(GO) test ./...

vet: ## Executar análise estática Go
	$(GO) vet ./...

check: fmt test vet ## Formatar e validar código Go

build: ## Compilar aplicação Go
	@mkdir -p $(BIN_DIR)
	$(GO) build -o $(BIN_DIR)/$(APP) ./cmd/server

up: ## Iniciar infraestrutura
	$(COMPOSE) up -d

rebuild: ## Reconstruir imagens e iniciar infraestrutura
	$(COMPOSE) up -d --build

down: ## Parar containers sem remover volumes
	$(COMPOSE) down

restart: ## Reiniciar containers
	$(COMPOSE) restart

ps: ## Exibir estado dos containers
	$(COMPOSE) ps

logs: ## Acompanhar logs (SERVICE=nginx opcional)
	$(COMPOSE) logs -f --tail=100 $(SERVICE)


validate: ## Validar API, Prometheus e Grafana
	@set -eu; \
	check_service() { \
		name="$$1"; \
		url="$$2"; \
		pattern="$$3"; \
		echo "Validando $$name..."; \
		attempt=1; \
		while [ "$$attempt" -le 10 ]; do \
			if $(CURL) --fail --silent --show-error --max-time 5 "$$url" 2>/dev/null | grep -Eq "$$pattern"; then \
				echo "[OK] $$name"; \
				return 0; \
			fi; \
			attempt=$$((attempt + 1)); \
			if [ "$$attempt" -le 10 ]; then sleep 3; fi; \
		done; \
		echo "[ERROR] $$name indisponível ou com resposta inválida."; \
		echo "Consulte: make ps e make logs"; \
		return 1; \
	}; \
	check_service "API" "http://localhost/projeto-korp" '"nome"[[:space:]]*:[[:space:]]*"Projeto Korp"' && \
	check_service "Prometheus" "http://127.0.0.1:9090/-/healthy" 'Prometheus Server is Healthy' && \
	check_service "Grafana" "http://127.0.0.1:3000/api/health" '"database"[[:space:]]*:[[:space:]]*"ok"'


ansible-deps: ## Instalar collection do Ansible
	$(ANSIBLE_GALAXY) collection install -r $(REQUIREMENTS)

ansible-check: ## Validar sintaxe do Ansible
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --syntax-check

provision: ## Provisionar ambiente com Ansible
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --ask-become-pass

clean: ## Remover somente artefatos locais de build
	rm -rf $(BIN_DIR)
