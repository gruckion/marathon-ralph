#!/bin/bash
# Project Detection Script
# Detects language, package manager, monorepo structure, and returns standardized commands
# Usage: ./detect.sh /path/to/project

set -e

PROJECT_DIR="${1:-.}"

# Change to project directory
cd "$PROJECT_DIR" 2>/dev/null || {
    echo '{"error": "Invalid project directory: '"$PROJECT_DIR"'"}'
    exit 1
}

# Initialize variables
LANGUAGE=""
PACKAGE_MANAGER=""
MONOREPO_TYPE="none"
WORKSPACES="[]"

# ============================================================================
# Language Detection
# ============================================================================

if [ -f "package.json" ]; then
    LANGUAGE="node"
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    LANGUAGE="python"
elif [ -f "go.mod" ]; then
    LANGUAGE="go"
elif [ -f "Cargo.toml" ]; then
    LANGUAGE="rust"
elif [ -f "build.gradle" ] || [ -f "pom.xml" ]; then
    LANGUAGE="java"
else
    LANGUAGE="unknown"
fi

# ============================================================================
# Node.js Package Manager Detection
# ============================================================================

if [ "$LANGUAGE" = "node" ]; then
    if [ -f "bun.lock" ] || [ -f "bun.lockb" ]; then
        PACKAGE_MANAGER="bun"
    elif [ -f "pnpm-lock.yaml" ]; then
        PACKAGE_MANAGER="pnpm"
    elif [ -f "yarn.lock" ]; then
        PACKAGE_MANAGER="yarn"
    elif [ -f "package-lock.json" ]; then
        PACKAGE_MANAGER="npm"
    else
        # Default to npm if no lock file found
        PACKAGE_MANAGER="npm"
    fi
fi

# ============================================================================
# Python Package Manager Detection
# ============================================================================

if [ "$LANGUAGE" = "python" ]; then
    if [ -f "poetry.lock" ]; then
        PACKAGE_MANAGER="poetry"
    elif [ -f "Pipfile.lock" ]; then
        PACKAGE_MANAGER="pipenv"
    elif [ -f "uv.lock" ]; then
        PACKAGE_MANAGER="uv"
    elif [ -f "requirements.txt" ]; then
        PACKAGE_MANAGER="pip"
    elif [ -f "pyproject.toml" ]; then
        # Check if it's poetry or another tool
        if grep -q '\[tool.poetry\]' pyproject.toml 2>/dev/null; then
            PACKAGE_MANAGER="poetry"
        else
            PACKAGE_MANAGER="pip"
        fi
    else
        PACKAGE_MANAGER="pip"
    fi
fi

# ============================================================================
# Monorepo Detection
# ============================================================================

if [ -f "turbo.json" ]; then
    MONOREPO_TYPE="turbo"
elif [ -f "nx.json" ]; then
    MONOREPO_TYPE="nx"
elif [ -f "lerna.json" ]; then
    MONOREPO_TYPE="lerna"
elif [ -f "pnpm-workspace.yaml" ]; then
    MONOREPO_TYPE="pnpm-workspaces"
elif [ -f "package.json" ]; then
    # Check for workspaces field in package.json
    if grep -q '"workspaces"' package.json 2>/dev/null; then
        MONOREPO_TYPE="npm-workspaces"
    fi
fi

# ============================================================================
# Workspace Detection (for monorepos)
# ============================================================================

if [ "$MONOREPO_TYPE" != "none" ] && [ -f "package.json" ]; then
    # Extract workspaces from package.json if present
    if command -v jq &>/dev/null; then
        # First try .workspaces.packages (nested format)
        WORKSPACES=$(jq -c '.workspaces.packages // null' package.json 2>/dev/null)

        # If null or empty, try .workspaces directly (might be array or object)
        if [ "$WORKSPACES" = "null" ] || [ -z "$WORKSPACES" ]; then
            # Check if .workspaces is an array
            IS_ARRAY=$(jq -r '.workspaces | if type == "array" then "yes" else "no" end' package.json 2>/dev/null)
            if [ "$IS_ARRAY" = "yes" ]; then
                WORKSPACES=$(jq -c '.workspaces' package.json 2>/dev/null || echo "[]")
            else
                WORKSPACES="[]"
            fi
        fi
    else
        # Fallback: grep for common workspace patterns
        WORKSPACES="[]"
        if [ -d "apps" ]; then
            WORKSPACES='["apps/*"]'
        fi
        if [ -d "packages" ]; then
            if [ "$WORKSPACES" = "[]" ]; then
                WORKSPACES='["packages/*"]'
            else
                WORKSPACES='["apps/*", "packages/*"]'
            fi
        fi
    fi
fi

# ============================================================================
# Command Generation
# ============================================================================

generate_node_commands() {
    local pm="$1"
    local monorepo="$2"

    case "$pm" in
        bun)
            INSTALL="bun install"
            RUN="bun run"
            EXEC="bunx"
            ;;
        pnpm)
            INSTALL="pnpm install"
            RUN="pnpm run"
            EXEC="pnpm exec"
            ;;
        yarn)
            INSTALL="yarn install"
            RUN="yarn"
            EXEC="yarn"
            ;;
        npm|*)
            INSTALL="npm install"
            RUN="npm run"
            EXEC="npx"
            ;;
    esac

    # Workspace-specific commands for monorepos
    case "$monorepo" in
        turbo)
            TEST_WORKSPACE="$RUN --filter={workspace} test"
            BUILD_WORKSPACE="$RUN --filter={workspace} build"
            # If turbo is available, prefer turbo run for all workspaces
            TEST_ALL="turbo run test"
            BUILD_ALL="turbo run build"
            ;;
        nx)
            TEST_WORKSPACE="nx test {workspace}"
            BUILD_WORKSPACE="nx build {workspace}"
            TEST_ALL="nx run-many --target=test"
            BUILD_ALL="nx run-many --target=build"
            ;;
        lerna)
            TEST_WORKSPACE="lerna run test --scope={workspace}"
            BUILD_WORKSPACE="lerna run build --scope={workspace}"
            TEST_ALL="lerna run test"
            BUILD_ALL="lerna run build"
            ;;
        pnpm-workspaces)
            TEST_WORKSPACE="pnpm --filter {workspace} test"
            BUILD_WORKSPACE="pnpm --filter {workspace} build"
            TEST_ALL="pnpm -r test"
            BUILD_ALL="pnpm -r build"
            ;;
        npm-workspaces)
            TEST_WORKSPACE="npm run test --workspace={workspace}"
            BUILD_WORKSPACE="npm run build --workspace={workspace}"
            TEST_ALL="npm run test --workspaces"
            BUILD_ALL="npm run build --workspaces"
            ;;
        *)
            TEST_WORKSPACE="$RUN test"
            BUILD_WORKSPACE="$RUN build"
            TEST_ALL="$RUN test"
            BUILD_ALL="$RUN build"
            ;;
    esac

    # Check if root has test script
    HAS_ROOT_TEST="false"
    if [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
        HAS_ROOT_TEST="true"
    fi

    cat << EOF
{
  "install": "$INSTALL",
  "dev": "$RUN dev",
  "build": "$BUILD_ALL",
  "buildWorkspace": "$BUILD_WORKSPACE",
  "test": "$TEST_ALL",
  "testWorkspace": "$TEST_WORKSPACE",
  "lint": "$RUN lint",
  "typecheck": "$RUN check-types",
  "exec": "$EXEC",
  "hasRootTest": $HAS_ROOT_TEST
}
EOF
}

generate_python_commands() {
    local pm="$1"

    # Check for poe (poethepoet) task runner
    local HAS_POE="false"
    if [ -f "pyproject.toml" ] && grep -q '\[tool\.poe' pyproject.toml 2>/dev/null; then
        HAS_POE="true"
    fi

    # If poe is available, prefer poe commands
    if [ "$HAS_POE" = "true" ]; then
        case "$pm" in
            poetry)
                cat << EOF
{
  "install": "poetry install",
  "dev": "poe dev",
  "build": "poetry build",
  "test": "poe test",
  "lint": "poe lint",
  "typecheck": "poe typecheck",
  "exec": "poetry run",
  "taskRunner": "poe"
}
EOF
                ;;
            *)
                cat << EOF
{
  "install": "pip install -r requirements.txt",
  "dev": "poe dev",
  "build": "python -m build",
  "test": "poe test",
  "lint": "poe lint",
  "typecheck": "poe typecheck",
  "exec": "python -m",
  "taskRunner": "poe"
}
EOF
                ;;
        esac
        return
    fi

    case "$pm" in
        poetry)
            cat << EOF
{
  "install": "poetry install",
  "dev": "poetry run python -m {module}",
  "build": "poetry build",
  "test": "poetry run pytest",
  "lint": "poetry run ruff check .",
  "typecheck": "poetry run mypy .",
  "exec": "poetry run"
}
EOF
            ;;
        pipenv)
            cat << EOF
{
  "install": "pipenv install",
  "dev": "pipenv run python -m {module}",
  "build": "pipenv run python -m build",
  "test": "pipenv run pytest",
  "lint": "pipenv run ruff check .",
  "typecheck": "pipenv run mypy .",
  "exec": "pipenv run"
}
EOF
            ;;
        uv)
            cat << EOF
{
  "install": "uv pip install -r requirements.txt",
  "dev": "uv run python -m {module}",
  "build": "uv run python -m build",
  "test": "uv run pytest",
  "lint": "uv run ruff check .",
  "typecheck": "uv run mypy .",
  "exec": "uv run"
}
EOF
            ;;
        pip|*)
            cat << EOF
{
  "install": "pip install -r requirements.txt",
  "dev": "python -m {module}",
  "build": "python -m build",
  "test": "pytest",
  "lint": "ruff check .",
  "typecheck": "mypy .",
  "exec": "python -m"
}
EOF
            ;;
    esac
}

generate_go_commands() {
    cat << EOF
{
  "install": "go mod download",
  "dev": "go run .",
  "build": "go build -o bin/",
  "test": "go test ./...",
  "lint": "golangci-lint run",
  "typecheck": "go vet ./..."
}
EOF
}

generate_rust_commands() {
    cat << EOF
{
  "install": "cargo fetch",
  "dev": "cargo run",
  "build": "cargo build --release",
  "test": "cargo test",
  "lint": "cargo clippy",
  "typecheck": "cargo check"
}
EOF
}

# Generate commands based on language
case "$LANGUAGE" in
    node)
        COMMANDS=$(generate_node_commands "$PACKAGE_MANAGER" "$MONOREPO_TYPE")
        ;;
    python)
        COMMANDS=$(generate_python_commands "$PACKAGE_MANAGER")
        ;;
    go)
        COMMANDS=$(generate_go_commands)
        ;;
    rust)
        COMMANDS=$(generate_rust_commands)
        ;;
    *)
        COMMANDS='{}'
        ;;
esac

# ============================================================================
# Output JSON Result
# ============================================================================

cat << EOF
{
  "language": "$LANGUAGE",
  "packageManager": "$PACKAGE_MANAGER",
  "monorepo": {
    "type": "$MONOREPO_TYPE",
    "workspaces": $WORKSPACES
  },
  "commands": $COMMANDS,
  "projectRoot": "$(pwd)"
}
EOF
