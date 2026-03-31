#!/usr/bin/env bash
# Tests for depbot-gen script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_SCRIPT="$SCRIPT_DIR/../depbot-gen"
PASS=0
FAIL=0
TESTS_RUN=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

setup_repo() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # Resolve symlinks (macOS /var -> /private/var) so pwd matches git toplevel
  tmpdir=$(cd "$tmpdir" && pwd -P)
  cd "$tmpdir"
  git init -q
  git commit -q --allow-empty -m "init"
  echo "$tmpdir"
}

cleanup() {
  if [ -n "${TEST_DIR:-}" ] && [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}

assert_contains() {
  local file="$1" pattern="$2" msg="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: $msg"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC}: $msg"
    echo "    Expected pattern: $pattern"
    echo "    In file: $file"
  fi
}

assert_not_contains() {
  local file="$1" pattern="$2" msg="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! grep -q "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: $msg"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC}: $msg"
    echo "    Did not expect pattern: $pattern"
    echo "    In file: $file"
  fi
}

assert_exit_code() {
  local expected="$1" actual="$2" msg="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" -eq "$actual" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: $msg"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC}: $msg"
    echo "    Expected exit code: $expected, got: $actual"
  fi
}

assert_output_contains() {
  local output="$1" pattern="$2" msg="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if echo "$output" | grep -qF -- "$pattern"; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: $msg"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC}: $msg"
    echo "    Expected pattern: $pattern"
    echo "    In output"
  fi
}

# --- Test: not a git repo ---
test_not_git_repo() {
  echo "TEST: Rejects non-git directory"
  local tmpdir
  tmpdir=$(mktemp -d)
  tmpdir=$(cd "$tmpdir" && pwd -P)
  cd "$tmpdir"
  local exit_code=0
  bash "$SCAN_SCRIPT" 2>/dev/null || exit_code=$?
  assert_exit_code 1 "$exit_code" "exits with code 1"
  rm -rf "$tmpdir"
}

# --- Test: not repo root ---
test_not_repo_root() {
  echo "TEST: Rejects non-root of git repo"
  TEST_DIR=$(setup_repo)
  mkdir -p "$TEST_DIR/subdir"
  cd "$TEST_DIR/subdir"
  local exit_code=0
  bash "$SCAN_SCRIPT" 2>/dev/null || exit_code=$?
  assert_exit_code 1 "$exit_code" "exits with code 1 from subdirectory"
  cleanup
}

# --- Test: no ecosystems found ---
test_no_ecosystems() {
  echo "TEST: No ecosystems found"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  touch readme.txt
  local exit_code=0
  bash "$SCAN_SCRIPT" 2>/dev/null || exit_code=$?
  assert_exit_code 1 "$exit_code" "exits with code 1 when no ecosystems"
  cleanup
}

# --- Test: detects npm ---
test_detect_npm() {
  echo "TEST: Detects npm ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "npm"' "npm ecosystem detected"
  assert_contains .github/dependabot.yml 'cooldown:' "cooldown present"
  assert_contains .github/dependabot.yml "days: 7" "cooldown days: 7"
  assert_contains .github/dependabot.yml 'interval: "weekly"' "weekly schedule"
  assert_contains .github/dependabot.yml 'day: "monday"' "monday schedule"
  cleanup
}

# --- Test: detects terraform ---
test_detect_terraform() {
  echo "TEST: Detects terraform ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo 'resource "aws_instance" "test" {}' > main.tf
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: terraform' "terraform ecosystem detected"
  assert_contains .github/dependabot.yml 'open-pull-requests-limit: 0' "security-updates only"
  assert_contains .github/dependabot.yml 'interval: "daily"' "daily schedule for terraform"
  assert_contains .github/dependabot.yml 'cooldown:' "cooldown present"
  cleanup
}

# --- Test: detects docker ---
test_detect_docker() {
  echo "TEST: Detects docker ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo 'FROM node:18' > Dockerfile
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "docker"' "docker ecosystem detected"
  cleanup
}

# --- Test: detects github-actions ---
test_detect_github_actions() {
  echo "TEST: Detects github-actions ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  mkdir -p .github/workflows
  cat > .github/workflows/ci.yml <<'YML'
name: CI
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
YML
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "github-actions"' "github-actions detected"
  cleanup
}

# --- Test: detects python/pip ---
test_detect_pip() {
  echo "TEST: Detects pip ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo 'flask==2.0' > requirements.txt
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "pip"' "pip ecosystem detected"
  cleanup
}

# --- Test: detects go ---
test_detect_gomod() {
  echo "TEST: Detects gomod ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo 'module example.com/test' > go.mod
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "gomod"' "gomod ecosystem detected"
  cleanup
}

# --- Test: detects cargo/rust ---
test_detect_cargo() {
  echo "TEST: Detects cargo ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo -e '[package]\nname = "test"' > Cargo.toml
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "cargo"' "cargo ecosystem detected"
  cleanup
}

# --- Test: detects gradle ---
test_detect_gradle() {
  echo "TEST: Detects gradle ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo 'apply plugin: "java"' > build.gradle
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "gradle"' "gradle ecosystem detected"
  cleanup
}

# --- Test: detects maven ---
test_detect_maven() {
  echo "TEST: Detects maven ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '<project><modelVersion>4.0.0</modelVersion></project>' > pom.xml
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "maven"' "maven ecosystem detected"
  cleanup
}

# --- Test: detects swift ---
test_detect_swift() {
  echo "TEST: Detects swift ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo 'import PackageDescription' > Package.swift
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "swift"' "swift ecosystem detected"
  cleanup
}

# --- Test: detects helm ---
test_detect_helm() {
  echo "TEST: Detects helm ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  mkdir -p helm/myapp
  cat > helm/myapp/Chart.yaml <<'YML'
apiVersion: v2
name: myapp
version: 0.1.0
YML
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "helm"' "helm ecosystem detected"
  cleanup
}

# --- Test: detects nuget ---
test_detect_nuget() {
  echo "TEST: Detects nuget ecosystem"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '' > test.sln
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "nuget"' "nuget ecosystem detected"
  cleanup
}

# --- Test: multiple ecosystems ---
test_multiple_ecosystems() {
  echo "TEST: Detects multiple ecosystems"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  echo 'FROM node:18' > Dockerfile
  echo 'flask==2.0' > requirements.txt
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'package-ecosystem: "npm"' "npm detected in multi"
  assert_contains .github/dependabot.yml 'package-ecosystem: "docker"' "docker detected in multi"
  assert_contains .github/dependabot.yml 'package-ecosystem: "pip"' "pip detected in multi"
  cleanup
}

# --- Test: no registry when flags absent ---
test_no_registry() {
  echo "TEST: No registry block when flags absent"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_not_contains .github/dependabot.yml 'registries:' "no registries block"
  assert_not_contains .github/dependabot.yml 'private-registry' "no registry reference"
  cleanup
}

# --- Test: registry flags add registry block ---
test_registry_flags() {
  echo "TEST: Registry flags add registry block"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  bash "$SCAN_SCRIPT" --registry-url "https://npm.example.com" --registry-type "npm-registry" --registry-token '${{secrets.NPM_TOKEN}}' 2>/dev/null || true
  assert_contains .github/dependabot.yml 'private-registry' "registry reference present"
  assert_contains .github/dependabot.yml 'npm-registry' "registry type present"
  assert_contains .github/dependabot.yml 'https://npm.example.com' "registry url present"
  assert_contains .github/dependabot.yml 'registries:' "registries block present"
  cleanup
}

# --- Test: YAML structure ---
test_yaml_structure() {
  echo "TEST: Valid YAML structure"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'version: 2' "version 2 header"
  assert_contains .github/dependabot.yml 'updates:' "updates section"
  assert_contains .github/dependabot.yml 'groups:' "groups section"
  assert_contains .github/dependabot.yml 'minor-and-patch:' "minor-and-patch group"
  cleanup
}

# --- Test: .github dir created ---
test_github_dir_created() {
  echo "TEST: Creates .github directory if missing"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  [ ! -d .github ] || rmdir .github 2>/dev/null || true
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -d .github ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: .github directory created"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC}: .github directory not created"
  fi
  cleanup
}

# --- Test: excludes node_modules ---
test_excludes_node_modules() {
  echo "TEST: Excludes node_modules"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  mkdir -p node_modules/dep
  echo '{"name":"dep"}' > node_modules/dep/package.json
  mkdir -p src
  echo 'module example.com/test' > src/go.mod
  bash "$SCAN_SCRIPT" 2>/dev/null || true
  # Should detect npm (root) and gomod (src), but not extra npm from node_modules
  assert_contains .github/dependabot.yml 'package-ecosystem: "npm"' "npm from root"
  assert_contains .github/dependabot.yml 'package-ecosystem: "gomod"' "gomod from src"
  cleanup
}

# --- Test: --help flag ---
test_help_flag() {
  echo "TEST: --help flag"
  local output
  output=$(bash "$SCAN_SCRIPT" --help 2>&1)
  assert_output_contains "$output" "Usage: depbot-gen" "shows usage"
  assert_output_contains "$output" "--timezone" "shows timezone option"
  assert_output_contains "$output" "--dry-run" "shows dry-run option"
}

# --- Test: --version flag ---
test_version_flag() {
  echo "TEST: --version flag"
  local output
  output=$(bash "$SCAN_SCRIPT" --version 2>&1)
  assert_output_contains "$output" "depbot-gen" "shows version"
}

# --- Test: --dry-run flag ---
test_dry_run() {
  echo "TEST: --dry-run does not write file"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  local output
  output=$(bash "$SCAN_SCRIPT" --dry-run 2>&1) || true
  assert_output_contains "$output" 'package-ecosystem: "npm"' "dry-run shows npm"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ ! -f .github/dependabot.yml ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: file not written in dry-run mode"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC}: file was written in dry-run mode"
  fi
  cleanup
}

# --- Test: --timezone flag ---
test_timezone_flag() {
  echo "TEST: --timezone flag"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  bash "$SCAN_SCRIPT" --timezone "America/New_York" 2>/dev/null || true
  assert_contains .github/dependabot.yml 'America/New_York' "custom timezone applied"
  assert_not_contains .github/dependabot.yml 'Europe/Oslo' "default timezone not present"
  cleanup
}

# --- Test: --schedule flag ---
test_schedule_flag() {
  echo "TEST: --schedule flag"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  bash "$SCAN_SCRIPT" --schedule daily 2>/dev/null || true
  assert_contains .github/dependabot.yml 'interval: "daily"' "daily schedule applied"
  assert_not_contains .github/dependabot.yml 'day: "monday"' "no day for daily schedule"
  cleanup
}

# --- Test: unknown flag ---
test_unknown_flag() {
  echo "TEST: Rejects unknown flags"
  local exit_code=0
  bash "$SCAN_SCRIPT" --bogus 2>/dev/null || exit_code=$?
  assert_exit_code 1 "$exit_code" "exits with code 1 for unknown flag"
}

# --- Test: file generated message ---
test_generated_message() {
  echo "TEST: Shows generated message"
  TEST_DIR=$(setup_repo)
  cd "$TEST_DIR"
  echo '{"name":"test"}' > package.json
  local output
  output=$(bash "$SCAN_SCRIPT" 2>&1) || true
  assert_output_contains "$output" "Generated .github/dependabot.yml" "shows generated message"
  cleanup
}

# =====================
# Run all tests
# =====================
echo "================================================"
echo " depbot-gen test suite"
echo "================================================"
echo ""

test_not_git_repo
test_not_repo_root
test_no_ecosystems
test_detect_npm
test_detect_terraform
test_detect_docker
test_detect_github_actions
test_detect_pip
test_detect_gomod
test_detect_cargo
test_detect_gradle
test_detect_maven
test_detect_swift
test_detect_helm
test_detect_nuget
test_multiple_ecosystems
test_no_registry
test_registry_flags
test_yaml_structure
test_github_dir_created
test_excludes_node_modules
test_help_flag
test_version_flag
test_dry_run
test_timezone_flag
test_schedule_flag
test_unknown_flag
test_generated_message

echo ""
echo "================================================"
echo -e " Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${TESTS_RUN} total"
echo "================================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
