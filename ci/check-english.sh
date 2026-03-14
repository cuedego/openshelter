#!/usr/bin/env bash
set -euo pipefail

# Fails if Portuguese/non-English text patterns are detected in tracked files.
# Scope: docs, templates, IaC files, and common source/config text files.

readonly ACCENTED_CHARS_REGEX='[À-ÖØ-öø-ÿ]'
readonly PORTUGUESE_KEYWORDS_REGEX='\b(infraestrutura|praticas|práticas|estrutura|principios|princípios|estado|imutabilidade|segredos|promocao|promoção|credenciais|permissoes|permissões|planeje|aplique|valide|mudancas|mudanças|objetivo|evidencias|evidências|contexto|proposta|criterios|critérios|aceite|impacto|operacional|automacoes|automações|modulos|módulos|ambientes)\b'

mapfile -t files < <(
  git ls-files \
    '*.md' '*.yml' '*.yaml' '*.tf' '*.tfvars' '*.example' \
    '*.sh' '*.py' '*.ts' '*.js' '*.json' '*.txt'
)

readonly EXCLUDED_FILES_REGEX='^(ci/check-english\.sh)$'

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No tracked text files found for language check."
  exit 0
fi

failed=0

for file in "${files[@]}"; do
  [[ -f "$file" ]] || continue

  if [[ "$file" =~ $EXCLUDED_FILES_REGEX ]]; then
    continue
  fi

  if grep -nE "$ACCENTED_CHARS_REGEX" "$file" >/tmp/language-accent-matches.txt 2>/dev/null; then
    echo "[language-check] Non-English accented characters found in: $file"
    cat /tmp/language-accent-matches.txt
    failed=1
  fi

  if grep -nE -i "$PORTUGUESE_KEYWORDS_REGEX" "$file" >/tmp/language-keyword-matches.txt 2>/dev/null; then
    echo "[language-check] Portuguese keywords found in: $file"
    cat /tmp/language-keyword-matches.txt
    failed=1
  fi

done

if [[ $failed -ne 0 ]]; then
  echo "Language check failed: repository content must remain in English."
  exit 1
fi

echo "Language check passed: no Portuguese patterns detected."
