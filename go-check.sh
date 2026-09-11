#!/usr/bin/env bash
#
# go-check.sh - Automação de verificações de qualidade em projetos Go
#
# Autor: Engenheiro Jacivaldo Carvalho
# Descrição: Executa formatação, análise estática e testes (normal + verbose),
#            com logging, cores, timeout e relatório final.
#
# Uso: ./go-check.sh [opções]
#

set -o pipefail
# Não usamos 'set -e' porque queremos capturar erros individualmente

# ============================================================
# CONFIGURAÇÕES
# ============================================================
SCRIPT_NAME="$(basename "$0")"
LOG_DIR="./logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/go-check_${TIMESTAMP}.log"
TIMEOUT_FMT=60        # segundos
TIMEOUT_VET=120       # segundos
TIMEOUT_TEST=300      # segundos
TIMEOUT_TEST_V=600    # segundos (verbose costuma demorar mais)
FAIL_FAST=false

# ============================================================
# CORES (detecta se terminal suporta)
# ============================================================
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# ============================================================
# HELPERS DE LOG
# ============================================================
log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] [$level] $msg" >> "$LOG_FILE"
}

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; log "INFO"  "$*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; log "OK"    "$*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; log "WARN"  "$*"; }
err()   { echo -e "${RED}[FAIL]${NC}  $*"; log "ERROR" "$*"; }
title() { echo -e "\n${BOLD}${CYAN}===== $* =====${NC}"; log "TITLE" "$*"; }

# ============================================================
# HELPERS DE EXECUÇÃO
# ============================================================
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Executa um comando com timeout e captura de saída
# Uso: run_step "nome" "timeout_seg" cmd args...
run_step() {
    local name="$1"; shift
    local timeout_sec="$1"; shift

    title "$name"
    info "Comando: $*"
    info "Timeout: ${timeout_sec}s"

    local start_time end_time elapsed
    start_time=$(date +%s)

    local output exit_code
    if command_exists timeout; then
        output=$(timeout "${timeout_sec}s" "$@" 2>&1)
        exit_code=$?
    else
        output=$("$@" 2>&1)
        exit_code=$?
    fi

    end_time=$(date +%s)
    elapsed=$((end_time - start_time))

    # Log da saída completa
    {
        echo "----- OUTPUT: $name -----"
        echo "$output"
        echo "----- END OUTPUT (exit=$exit_code, ${elapsed}s) -----"
    } >> "$LOG_FILE"

    if [[ -n "$output" ]]; then
        echo "$output"
    fi

    if [[ $exit_code -eq 0 ]]; then
        ok "$name concluído com sucesso em ${elapsed}s"
        return 0
    elif [[ $exit_code -eq 124 ]]; then
        err "$name excedeu o timeout de ${timeout_sec}s"
        return 124
    else
        err "$name falhou (exit=$exit_code) após ${elapsed}s"
        return $exit_code
    fi
}

# ============================================================
# PARSE DE ARGUMENTOS
# ============================================================
show_help() {
    cat <<EOF
${BOLD}Uso:${NC} $SCRIPT_NAME [opções]

${BOLD}Opções:${NC}
  -f, --fail-fast      Para na primeira falha
  -n, --no-log         Não gera arquivo de log
  -c, --clean-cache    Executa 'go clean -testcache' antes dos testes
  -s, --skip-verbose   Pula a etapa 'go test -v ./...'
  -h, --help           Mostra esta ajuda

${BOLD}Descrição:${NC}
  Executa em sequência:
    1. go fmt ./...       (formatação)
    2. go vet ./...       (análise estática)
    3. go test ./...      (testes — saída resumida)
    4. go test -v ./...   (testes — saída verbosa, detalhada por caso)

${BOLD}Saída:${NC}
  Código 0 = tudo OK | Código >0 = alguma etapa falhou

${BOLD}Log:${NC}
  ${LOG_DIR}/go-check_<timestamp>.log
EOF
}

CLEAN_CACHE=false
USE_LOG=true
SKIP_VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--fail-fast)     FAIL_FAST=true ;;
        -n|--no-log)        USE_LOG=false ;;
        -c|--clean-cache)   CLEAN_CACHE=true ;;
        -s|--skip-verbose)  SKIP_VERBOSE=true ;;
        -h|--help)          show_help; exit 0 ;;
        *) err "Opção desconhecida: $1"; show_help; exit 1 ;;
    esac
    shift
done

# ============================================================
# INICIALIZAÇÃO
# ============================================================
if [[ "$USE_LOG" == true ]]; then
    mkdir -p "$LOG_DIR"
    : > "$LOG_FILE"
else
    LOG_FILE="/dev/null"
fi

echo -e "${BOLD}${CYAN}"
echo "======================================================"
echo "  Go Quality Check - $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================"
echo -e "${NC}"

# Verifica se Go está instalado
if ! command_exists go; then
    err "Go não encontrado no PATH. Instale o Go antes de continuar."
    exit 127
fi

info "Versão do Go: $(go version)"
info "Diretório: $(pwd)"
info "Log: $LOG_FILE"
[[ "$SKIP_VERBOSE" == true ]] && info "Modo --skip-verbose ativado: etapa 'go test -v' será pulada."

# Verifica se estamos em um módulo Go
if [[ ! -f "go.mod" ]]; then
    warn "Arquivo go.mod não encontrado no diretório atual."
    warn "Executando mesmo assim — pode falhar se não estiver em um módulo."
fi

# ============================================================
# EXECUÇÃO DAS ETAPAS
# ============================================================
declare -A RESULTS
EXIT_CODE=0

# --- 0. Limpeza opcional do cache de testes ---
if [[ "$CLEAN_CACHE" == true ]]; then
    if ! run_step "go clean -testcache" 60 go clean -testcache; then
        warn "Falha ao limpar cache, prosseguindo..."
    fi
fi

# --- 1. go fmt ---
if run_step "go fmt ./..." "$TIMEOUT_FMT" go fmt ./...; then
    RESULTS["fmt"]="OK"
else
    RESULTS["fmt"]="FAIL($?)"
    EXIT_CODE=1
    if [[ "$FAIL_FAST" == true ]]; then
        warn "Fail-fast ativado. Abortando."
        print_summary
        exit $EXIT_CODE
    fi
fi

# --- 2. go vet ---
if run_step "go vet ./..." "$TIMEOUT_VET" go vet ./...; then
    RESULTS["vet"]="OK"
else
    RESULTS["vet"]="FAIL($?)"
    EXIT_CODE=1
    if [[ "$FAIL_FAST" == true ]]; then
        warn "Fail-fast ativado. Abortando."
        print_summary
        exit $EXIT_CODE
    fi
fi

# --- 3. go test (resumido) ---
if run_step "go test ./..." "$TIMEOUT_TEST" go test ./...; then
    RESULTS["test"]="OK"
else
    RESULTS["test"]="FAIL($?)"
    EXIT_CODE=1
    if [[ "$FAIL_FAST" == true ]]; then
        warn "Fail-fast ativado. Abortando."
        print_summary
        exit $EXIT_CODE
    fi
fi

# --- 4. go test -v (verboso) ---
if [[ "$SKIP_VERBOSE" == true ]]; then
    RESULTS["test-v"]="SKIP"
    info "Etapa 'go test -v ./...' pulada por configuração."
else
    if run_step "go test -v ./..." "$TIMEOUT_TEST_V" go test -v ./...; then
        RESULTS["test-v"]="OK"
    else
        RESULTS["test-v"]="FAIL($?)"
        EXIT_CODE=1
        if [[ "$FAIL_FAST" == true ]]; then
            warn "Fail-fast ativado. Abortando."
            print_summary
            exit $EXIT_CODE
        fi
    fi
fi

# ============================================================
# RELATÓRIO FINAL
# ============================================================
print_summary() {
    title "RELATÓRIO FINAL"
    printf "  %-12s : %s\n" "go fmt"        "${RESULTS[fmt]:-SKIP}"
    printf "  %-12s : %s\n" "go vet"        "${RESULTS[vet]:-SKIP}"
    printf "  %-12s : %s\n" "go test"       "${RESULTS[test]:-SKIP}"
    printf "  %-12s : %s\n" "go test -v"    "${RESULTS[test-v]:-SKIP}"
    echo
    if [[ $EXIT_CODE -eq 0 ]]; then
        ok "Todas as verificações passaram com sucesso."
    else
        err "Uma ou mais verificações falharam."
    fi
    info "Log completo: $LOG_FILE"
}

print_summary
exit $EXIT_CODE