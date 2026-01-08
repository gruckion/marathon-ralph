# feat: Parallelize workflow tasks for improved performance

## Parallelization Analysis

Based on a review of marathon-ralph's architecture, here's an analysis of parallelization opportunities.

---

## Part 1: Parallelizing Task Creation from Specs

### Current State
The init agent reads a spec and creates Linear issues sequentially with implicit ordering via priorities (P0→P1→P2→P3). There's **no explicit dependency tracking** between issues.

### Parallelization Opportunity: Dependency Graph

The spec structure already hints at dependencies:

```xml
<implementation_steps>
  <step number="1">Setup and Database</step>     <!-- foundational -->
  <step number="2">API Routes</step>             <!-- depends on DB -->
  <step number="3">UI Implementation</step>      <!-- depends on API -->
  <step number="4">Polish</step>                 <!-- depends on UI -->
</implementation_steps>
```

**What could be parallelized within each step:**

| Step | Tasks | Parallelizable? |
|------|-------|-----------------|
| DB Setup | schema creation, migrations | Sequential (order matters) |
| API Routes | `todo.getAll`, `todo.create`, `todo.update`, `todo.delete`, `todo.toggle` | **Yes** - independent endpoints |
| UI Components | TodoList, TodoItem, AddForm | **Partial** - components can be built independently, wiring is sequential |
| Polish | loading states, toasts, linting | **Yes** - independent polish items |

### Proposed Enhancement: Dependency Metadata

Add explicit dependency tracking to issues:

```json
{
  "current_issue": {
    "id": "PROJ-5",
    "identifier": "PROJ-5",
    "title": "[API] Create todo.getAll endpoint",
    "dependencies": ["PROJ-2"],
    "blocks": ["PROJ-10"]
  }
}
```

**Detection heuristics from spec:**
1. Steps with lower numbers are dependencies for higher numbers
2. Within a step, tasks are often parallelizable unless they reference each other
3. Database/schema always blocks API; API always blocks UI

---

## Part 2: Parallelizing the Workflow Loop

### Current Sequential Flow

```
VERIFY → PLAN → CODE → TEST → QA → EXIT
   ↓        ↓      ↓      ↓      ↓     ↓
 ~30s    ~60s   ~180s  ~120s  ~120s  ~10s  = ~520s total
```

### Phase Dependency Analysis

| Phase | Depends On | Produces | Side Effects |
|-------|------------|----------|--------------|
| VERIFY | Previous code state | Pass/fail + health check | None (read-only) |
| PLAN | VERIFY pass + issue | Implementation plan | None (read-only) |
| CODE | PLAN output | Implementation files | Files + commit |
| TEST | CODE output | Unit/integration tests | Files + commit |
| QA | CODE output | E2E tests | Files + commit |
| EXIT | TEST + QA complete | State update | State + Linear |

### Opportunity 1: TEST + QA in Parallel (High Value)

**Both depend only on CODE output**, not on each other:

```
VERIFY → PLAN → CODE → ┬─ TEST ─┬→ EXIT
                       └─  QA  ─┘
```

**Why this works:**
- TEST writes to `src/**/*.test.ts` or `__tests__/`
- QA writes to `tests/e2e/*.spec.ts`
- No file conflicts, no read dependency between them
- Both can run simultaneously, EXIT waits for both

**Estimated savings:** ~90-120s per issue (40-50% of TEST+QA time)

### Opportunity 2: Parallel Checks within VERIFY (Medium Value)

Current VERIFY runs sequentially:
```
tests → integration → e2e → lint → typecheck
```

Independent checks can run in parallel:
```
┬─ tests ─────────────┬
├─ integration tests ─┤→ aggregate results
├─ lint ──────────────┤
└─ typecheck ─────────┘
```

**Why this works:**
- All are read-only operations
- No shared state between checks
- All must pass for VERIFY to pass

**Estimated savings:** ~15-30s per issue (lint + types overlap with tests)

### Opportunity 3: Multi-Session Parallel Issues (Already Supported!)

The session scoping mechanism already enables this:

```
Session A (owns marathon):  Issue 1 → Issue 3 → Issue 5
Session B (manual):         Issue 2 (independent)
Session C (manual):         Issue 4 (independent)
```

**Limitation:** Requires manual session management and explicit dependency knowledge.

---

## Summary: What Can Be Parallelized

### Within Spec → Issues (init phase)

| Category | Parallelizable | Implementation |
|----------|----------------|----------------|
| Step parsing | No (order matters) | - |
| Issue creation within step | **Yes** | Create issues in parallel batches |
| Dependency detection | **Yes** | Analyze spec for implicit deps |

### Within Workflow Loop (per issue)

| Phases | Parallelizable | Est. Savings | Complexity |
|--------|----------------|--------------|------------|
| TEST + QA | **Yes** | 40-50% of those phases | Low |
| VERIFY checks | **Yes** | 15-30s per issue | Medium |
| PLAN + CODE | No (CODE needs PLAN) | - | - |
| Multiple issues | Already supported | Varies | High (deps needed) |

### Recommended Priority

1. **TEST + QA parallel** - Lowest complexity, highest impact
2. **VERIFY internal parallelism** - Medium complexity, moderate impact
3. **Dependency tracking for issues** - High complexity, enables future parallelism

---

## Implementation Tasks

- [ ] Implement parallel TEST + QA execution in `run.md` command
- [ ] Add parallel execution support for VERIFY checks (lint, typecheck, tests)
- [ ] Design dependency metadata schema for issues
- [ ] Update init agent to detect and record task dependencies from specs
- [ ] Document parallelization architecture in AGENTS.md
