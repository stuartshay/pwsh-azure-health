# Workflow Testing

Tests for GitHub Actions workflows and CI scripts.

## BATS Tests

BATS (Bash Automated Testing System) tests shell scripts used in workflows.

### Install BATS

```bash
./scripts/local/install-bats.sh
```

### Run Tests

```bash
# Run all workflow tests
bats tests/workflows/

# Run specific test file
bats tests/workflows/retry-utils.bats

# Verbose output with TAP format
bats --tap tests/workflows/retry-utils.bats
```

### Pre-commit Integration

BATS tests run automatically on modified shell scripts:

```bash
# Runs tests on commit for modified scripts
git commit

# Run manually
pre-commit run bats-tests --all-files
```

## Test Files

- `retry-utils.bats` - Tests for retry utility functions in `scripts/ci/retry-utils.sh`

## Writing Tests

```bash
#!/usr/bin/env bats

setup() {
  # Runs before each test
  source scripts/ci/retry-utils.sh
}

@test "description of test" {
  run command_to_test arg1 arg2
  [ "$status" -eq 0 ]
  [ "$output" = "expected output" ]
}
```

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
