---
name: project-detection
description: Detects project type, package manager, and monorepo structure. Returns correct commands for test/build/lint/dev. Run at project initialization and cache results in state. Use before running any build/test commands.
---

# Project Detection

Detects project configuration and provides standardized commands. Run once at init, cache in state file.

## Usage

Run the detection script from the project root:

```bash
./marathon-ralph/skills/project-detection/scripts/detect.sh /path/to/project
```

Returns JSON:

```json
{
  "language": "node",
  "packageManager": "bun",
  "monorepo": {
    "type": "turbo",
    "workspaces": ["apps/web", "apps/api", "packages/shared"]
  },
  "commands": {
    "install": "bun install",
    "dev": "bun run dev",
    "build": "bun run build",
    "test": "bun run test",
    "testWorkspace": "bun run --filter={workspace} test",
    "lint": "bun run lint",
    "typecheck": "bun run check-types"
  }
}
```

## Caching Results

After detection, store in marathon state file under `project` key:

```json
{
  "project": {
    "language": "node",
    "packageManager": "bun",
    "monorepo": { "type": "turbo", "workspaces": [...] },
    "commands": { ... },
    "detectedAt": "2024-01-03T12:00:00Z"
  }
}
```

## Using Cached Commands

When running commands, always check state first:

1. Read `project.commands` from state  
2. If not present, run detection script  
3. Use the appropriate command from the cache  

### For Monorepos

When tests/builds need to target a specific workspace:

```bash
# Use testWorkspace with the workspace name
bun run --filter=web test

# Or for all workspaces
turbo run test
```

### Command Selection Priority

1. Use cached command from state  
2. If no cache, run detection  
3. If detection fails, fall back to reference patterns  

## Detection Logic

### Package Manager Detection (by lock file)

| Lock File                      | Package Manager | Install               | Run        |
|--------------------------------|-----------------|-----------------------|------------|
| `bun.lock` or `bun.lockb`      | bun             | `bun install`         | `bun run`  |
| `pnpm-lock.yaml`               | pnpm            | `pnpm install`        | `pnpm run` |
| `yarn.lock`                    | yarn            | `yarn install`        | `yarn`     |
| `package-lock.json`            | npm             | `npm install`         | `npm run`  |

### Monorepo Detection

| Config File                        | Monorepo Type         |
|------------------------------------|-----------------------|
| `turbo.json`                       | Turborepo             |
| `nx.json`                          | Nx                    |
| `lerna.json`                       | Lerna                 |
| `pnpm-workspace.yaml`              | pnpm workspaces       |
| `package.json` with `workspaces`   | npm/yarn workspaces   |

### Language Detection

| Indicator                             | Language |
|---------------------------------------|----------|
| `package.json`                        | Node.js  |
| `pyproject.toml`, `setup.py`          | Python   |
| `go.mod`                              | Go       |
| `Cargo.toml`                          | Rust     |
| `build.gradle`, `pom.xml`             | Java     |

## Python Project Commands

For Python projects:

| Tool        | Install                                   | Run Script              | Test                  |
|-------------|-------------------------------------------|-------------------------|-----------------------|
| poetry      | `poetry install`                          | `poetry run {script}`   | `poetry run pytest`   |
| poetry+poe  | `poetry install`                          | `poe {task}`            | `poe test`            |
| pip + venv  | `pip install -r requirements.txt`         | `python -m {module}`    | `pytest`              |
| uv          | `uv pip install -r requirements.txt`      | `uv run {script}`       | `uv run pytest`       |
| pipenv      | `pipenv install`                          | `pipenv run {script}`   | `pipenv run pytest`   |

**Note:** If `[tool.poe.tasks]` exists in `pyproject.toml`, poe commands are preferred.

## Reference Files

- [node.md](node.md) - Node.js patterns and commands
- [python.md](python.md) - Python patterns and commands
- [monorepo.md](monorepo.md) - Monorepo-specific patterns
