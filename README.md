# depbot-gen

A bash script that scans a git repository for known package ecosystems and generates a `.github/dependabot.yml` configuration file.

## Installation

### Homebrew (macOS/Linux)

```bash
brew tap Glenn-Terjesen/depbot-gen
brew install depbot-gen
```

### From source

```bash
git clone https://github.com/Glenn-Terjesen/depbot-gen.git
cd depbot-gen
make install
```

To install to a custom prefix:

```bash
make install PREFIX=$HOME/.local
```

### Prerequisites

- `bash` 4+ (for associative arrays — macOS ships bash 3.2, use `brew install bash`)
- Must be run from the root of a git repository

## Usage

```bash
cd /path/to/your/repo
depbot-gen
```

### Options

```
  -h, --help              Show help message
  -v, --version           Show version
  -n, --dry-run           Print generated config to stdout without writing
  -t, --timezone ZONE     Timezone for schedule (default: UTC)
  -s, --schedule INTERVAL Schedule interval: daily, weekly, monthly (default: weekly)
  -d, --day DAY           Day of week for weekly schedule (default: monday)
      --time TIME         Time of day in HH:MM format (default: 09:00)
      --pr-limit N        Max open PRs per ecosystem (default: 2)
      --cooldown N        Cooldown days between batches (default: 7)
      --registry-url URL  Private registry URL (enables registry block)
      --registry-type T   Registry type: npm-registry, maven-repository, etc.
      --registry-token S  Registry token as secret ref, e.g. ${{secrets.MY_TOKEN}}
```

### Examples

```bash
# Preview without writing
depbot-gen --dry-run

# Custom timezone and daily schedule
depbot-gen --timezone America/New_York --schedule daily

# Increase PR limit and reduce cooldown
depbot-gen --pr-limit 5 --cooldown 3

# Private npm registry
depbot-gen --registry-url https://npm.pkg.github.com --registry-type npm-registry --registry-token '${{secrets.NPM_TOKEN}}'
```

## Supported ecosystems

| Ecosystem | Detected by |
|---|---|
| npm | `package.json` |
| gradle | `build.gradle` / `build.gradle.kts` |
| maven | `pom.xml` |
| nuget | `*.sln` |
| pip | `requirements.txt`, `setup.py`, `pyproject.toml` |
| cargo | `Cargo.toml` |
| gomod | `go.mod` |
| terraform | `*.tf` |
| docker | `Dockerfile` |
| github-actions | `.github/workflows/*.yml` |
| helm | `Chart.yaml` |
| swift | `Package.swift` |

## Features

- Automatically discovers ecosystems up to 5 directory levels deep
- Groups minor and patch version updates together
- Terraform is configured for security-updates only (`open-pull-requests-limit: 0`)
- Private registry support via `--registry-*` flags
- Configurable schedule, timezone, PR limits, and cooldown
- Dry-run mode for previewing output

## Generated configuration defaults

- **Schedule**: Weekly on Mondays at 09:00 UTC, daily for Terraform
- **PR limit**: 2 open PRs per ecosystem (0 for Terraform - security only)
- **Grouping**: Minor and patch updates grouped together
- **Cooldown**: 7 days between update batches

## Excluded paths

The scanner ignores files in these directories:

- `.git/`
- `node_modules/`
- `charts/`
- `.terraform/`
- `.venv/` / `venv/`

## Tests

```bash
make test
```

## License

MIT
