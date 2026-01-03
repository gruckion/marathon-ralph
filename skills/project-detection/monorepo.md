# Monorepo Patterns

## Detection

| Tool                 | Config File(s)                 | Detection                                  |
|----------------------|-------------------------------|---------------------------------------------|
| Turborepo            | `turbo.json`                  | Primary indicator                          |
| Nx                   | `nx.json`                     | Primary indicator                          |
| Lerna                | `lerna.json`                  | Primary indicator                          |
| pnpm workspaces      | `pnpm-workspace.yaml`         | Primary indicator                          |
| npm/yarn workspaces  | `package.json` (`workspaces`) | Presence of `workspaces` field in package   |

## Turborepo

### Config: `turbo.json`

```json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": []
    },
    "lint": {},
    "dev": {
      "cache": false,
      "persistent": true
    }
  }
}
```

### Commands

```bash
# Run task in all workspaces
turbo run test
turbo run build

# Run task in specific workspace
turbo run test --filter=web
turbo run test --filter=@myorg/api

# Using package manager with filter
bun run --filter=web test
pnpm --filter web test
```

### Adding New Tasks to Pipeline

To add a new task (like `test`) to the monorepo:

1. Add to `turbo.json`:

```json
{
  "pipeline": {
    "test": {
      "dependsOn": ["^build"],
      "outputs": []
    }
  }
}
```

1. Add to root `package.json`:

```json
{
  "scripts": {
    "test": "turbo run test"
  }
}
```

1. Add to workspace `package.json`:

```json
{
  "scripts": {
    "test": "vitest run"
  }
}
```

## Nx

### Nx Commands

```bash
# Run task in all projects
nx run-many --target=test
nx run-many --target=build

# Run task in specific project
nx test web
nx build api

# Run affected only
nx affected --target=test
```

## Lerna

### Lerna Commands

```bash
# Run in all packages
lerna run test
lerna run build

# Run in specific package
lerna run test --scope=@myorg/web
lerna run build --scope=api

# Run in changed packages
lerna run test --since=main
```

## pnpm Workspaces

### Config: `pnpm-workspace.yaml`

```yaml
packages:
  - 'apps/*'
  - 'packages/*'
```

### pnpm Commands

```bash
# Run in all workspaces
pnpm -r test
pnpm -r build

# Run in specific workspace
pnpm --filter web test
pnpm --filter @myorg/api build

# Run in workspace and dependencies
pnpm --filter web... test
```

## npm/yarn Workspaces

### Config: `package.json`

```json
{
  "workspaces": [
    "apps/*",
    "packages/*"
  ]
}
```

### npm Commands

```bash
# Run in all workspaces
npm run test --workspaces
npm run build --ws

# Run in specific workspace
npm run test --workspace=web
npm run build -w @myorg/api
```

### yarn Commands

```bash
# Run in all workspaces
yarn workspaces run test

# Run in specific workspace
yarn workspace web test
yarn workspace @myorg/api build
```

## Common Mistakes

### 1. Running at root without task defined

**Wrong:** `npm run test` (when root has no test script)
**Right:** `turbo run test` or `npm run test --workspaces`

### 2. Forgetting workspace filter

**Wrong:** `bun run test` (runs nothing in Turborepo)
**Right:** `bun run --filter=web test`

### 3. Using wrong filter syntax

| Tool      | Filter Syntax                                 |
|-----------|-----------------------------------------------|
| Turborepo | `--filter=name`<br>`--filter=@scope/name`     |
| pnpm      | `--filter name`<br>`--filter @scope/name`     |
| npm       | `--workspace=name`<br>`-w name`               |
| Lerna     | `--scope=name`<br>`--scope=@scope/name`       |

### 4. Missing root script

For `turbo run test` to work from `npm run test`:

```json
// root package.json
{
  "scripts": {
    "test": "turbo run test"
  }
}
```
