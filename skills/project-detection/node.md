# Node.js Project Patterns

## Package Managers

### Bun

- Lock file: `bun.lock` or `bun.lockb`
- Install: `bun install`
- Run script: `bun run <script>`
- Execute binary: `bunx <binary>`
- Add package: `bun add <pkg>` or `bun add -D <pkg>`

### pnpm

- Lock file: `pnpm-lock.yaml`
- Install: `pnpm install`
- Run script: `pnpm run <script>` or `pnpm <script>`
- Execute binary: `pnpm exec <binary>` or `pnpm dlx <binary>`
- Add package: `pnpm add <pkg>` or `pnpm add -D <pkg>`

### Yarn

- Lock file: `yarn.lock`
- Install: `yarn install` or `yarn`
- Run script: `yarn <script>`
- Execute binary: `yarn <binary>` or `yarn dlx <binary>`
- Add package: `yarn add <pkg>` or `yarn add -D <pkg>`

### npm

- Lock file: `package-lock.json`
- Install: `npm install`
- Run script: `npm run <script>`
- Execute binary: `npx <binary>`
- Add package: `npm install <pkg>` or `npm install -D <pkg>`

## Common Scripts

Most Node.js projects have these scripts in `package.json`:

| Script                       | Description                                 |
|------------------------------|---------------------------------------------|
| `dev`                        | Launches the development server             |
| `build`                      | Compiles and bundles for production         |
| `start`                      | Runs the production server                  |
| `test`                       | Executes all project tests                  |
| `test:run`, `test:ci`        | Runs tests once (suitable for CI pipelines) |
| `lint`                       | Checks code style and linting rules         |
| `typecheck`, `check-types`   | Performs TypeScript type checking           |

## Test Frameworks

### Vitest

```bash
# Run all tests
bun run test

# Run tests once (CI mode)
bun run test:run

# Run specific test file
bun run test src/components/Button.test.tsx

# Run tests matching pattern
bun run test --grep="Button"
```

### Jest

```bash
# Run all tests
npm run test

# Run specific file
npm run test -- path/to/file.test.ts

# Run tests matching pattern
npm run test -- --testPathPattern="Button"
```

## Common Issues

### Script Not Found

If `test` script doesn't exist at root, check:

1. Is this a monorepo? Use workspace filter
2. Is the script named differently? (`test:unit`, `test:run`)
3. Does the workspace have the script?

### Monorepo Commands

For monorepos, always use workspace filters:

```bash
# Turborepo
bun run --filter=web test
turbo run test --filter=web

# pnpm
pnpm --filter web test

# npm workspaces
npm run test --workspace=web
```
