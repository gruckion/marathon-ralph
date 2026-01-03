# Python Project Patterns

## Package Managers

### Poetry

- Config: `pyproject.toml` with `[tool.poetry]`
- Lock file: `poetry.lock`
- Install: `poetry install`
- Run command: `poetry run <command>`
- Add package: `poetry add <pkg>` or `poetry add -D <pkg>`
- Virtual env: Managed automatically

### Pipenv

- Config: `Pipfile`
- Lock file: `Pipfile.lock`
- Install: `pipenv install`
- Run command: `pipenv run <command>`
- Add package: `pipenv install <pkg>` or `pipenv install --dev <pkg>`
- Virtual env: Managed automatically

### uv (fast Python package manager)

- Config: `pyproject.toml` or `requirements.txt`
- Lock file: `uv.lock`
- Install: `uv pip install -r requirements.txt`
- Run command: `uv run <command>`
- Add package: `uv pip install <pkg>`
- Virtual env: `uv venv`

### pip (vanilla)

- Config: `requirements.txt` or `setup.py`
- Lock file: None (or `requirements.lock`)
- Install: `pip install -r requirements.txt`
- Run command: Direct execution or `python -m <module>`
- Add package: `pip install <pkg>`
- Virtual env: `python -m venv .venv`

## Task Runners

### Poe the Poet (poethepoet)

Task runner for Python, often used with Poetry. Defined in `pyproject.toml`:

```toml
[tool.poe.tasks]
test = "pytest"
lint = "ruff check ."
format = "ruff format ."
typecheck = "mypy ."
dev = "python -m myapp"
```

**Commands:**

```bash
# Run a task
poe test
poe lint
poe dev

# With poetry (if poe not globally installed)
poetry run poe test
```

**Detection:** Check for `[tool.poe.tasks]` in `pyproject.toml`

## Common Commands

### Testing

```bash
# Poetry
poetry run pytest
poetry run pytest -v               # verbose
poetry run pytest path/to/test.py  # specific file
poetry run pytest -k "test_name"   # matching pattern

# Pipenv
pipenv run pytest

# pip/venv
pytest
python -m pytest
```

### Linting

```bash
# Ruff (fast, recommended)
poetry run ruff check .
poetry run ruff check --fix .

# Flake8
poetry run flake8

# Black (formatting)
poetry run black .
poetry run black --check .
```

### Type Checking

```bash
# MyPy
poetry run mypy .
poetry run mypy src/

# Pyright
poetry run pyright
```

## Project Structure

### Standard Package Layout

```markdown
my-project/
├── pyproject.toml
├── src/
│   └── my_package/
│       ├── __init__.py
│       └── main.py
├── tests/
│   ├── __init__.py
│   └── test_main.py
└── README.md
```

### Flat Layout

```markdown
my-project/
├── pyproject.toml
├── my_package/
│   ├── __init__.py
│   └── main.py
├── tests/
│   └── test_main.py
└── README.md
```

## Python Monorepos

### Using Poetry Workspaces

Not natively supported, but can use:

- Separate `pyproject.toml` per package
- Path dependencies: `my-package = { path = "../my-package" }`

### Using pip with editable installs

```bash
pip install -e packages/core
pip install -e packages/api
```

### Common Monorepo Tools

- **Pants**: `pants test ::`
- **Bazel**: `bazel test //...`
- **Hatch**: `hatch run test`
