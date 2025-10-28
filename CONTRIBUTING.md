# Contributing to Azure Health Monitoring Functions

Thank you for your interest in contributing! This document provides guidelines and best practices for contributing to this project.

## Code of Conduct

This project follows standard open source community guidelines. Please be respectful and constructive in all interactions.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Follow the [Local Development Setup Guide](docs/SETUP.md)
4. Create a new branch for your changes

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

Branch naming conventions:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Test additions or changes

### 2. Make Your Changes

Follow these guidelines:

#### PowerShell Code Style
- Use 4 spaces for indentation
- Follow [PowerShell Best Practices](https://poshcode.gitbooks.io/powershell-practice-and-style/)
- Use approved verbs for functions (`Get-`, `Set-`, `New-`, etc.)
- Include comment-based help for functions
- Use meaningful variable names

Example:
```powershell
<#
.SYNOPSIS
    Brief description of what the function does.

.DESCRIPTION
    Detailed description of the function.

.PARAMETER ParameterName
    Description of the parameter.

.EXAMPLE
    Example of how to use the function.
#>
function Get-ServiceHealthData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId
    )
    
    # Implementation
}
```

#### Error Handling
Always include proper error handling:

```powershell
try {
    # Your code
    $result = Get-SomeData -ErrorAction Stop
}
catch {
    Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
```

#### Logging
Use appropriate logging levels:

```powershell
Write-Host "Processing started..." -ForegroundColor Cyan
Write-Host "Retrieved $count items" -ForegroundColor Green
Write-Host "Warning: No data found" -ForegroundColor Yellow
Write-Host "Error: Failed to connect" -ForegroundColor Red
```

### 3. Test Your Changes

Before submitting:

```bash
# Start the function locally
func start --script-root src

# Test the function
curl "http://localhost:7071/api/GetServiceHealth?SubscriptionId=your-sub-id"

# Verify no errors in the console output
```

### 4. Update Documentation

- Update README.md if you've added new features
- Update relevant documentation in the `docs/` folder
- Add comments to complex code sections
- Update function-level documentation

### 5. Commit Your Changes

Follow conventional commit messages:

```
feat: add new service health alert function
fix: resolve timeout issue in GetServiceHealth
docs: update deployment guide
refactor: improve error handling in main function
test: add integration tests for health endpoint
```

Commit message format:
```
<type>: <subject>

<body>

<footer>
```

Types:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Formatting changes
- `refactor` - Code refactoring
- `test` - Tests
- `chore` - Maintenance

### 6. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub with:
- Clear title describing the change
- Description of what changed and why
- Reference any related issues
- Screenshots if UI changes

## Pull Request Guidelines

### PR Checklist

- [ ] Code follows the project style guidelines
- [ ] Comments added to complex code sections
- [ ] Documentation updated as needed
- [ ] All tests pass locally
- [ ] No new warnings or errors
- [ ] Commit messages follow conventions
- [ ] PR description is clear and complete

### Review Process

1. Automated checks will run on your PR
2. Maintainers will review your code
3. Address any requested changes
4. Once approved, your PR will be merged

## Adding New Functions

When adding a new Azure Function:

1. Create a new directory under `src/`: `src/MyNewFunction/`
2. Add `function.json` with appropriate bindings
3. Add `run.ps1` with the implementation
4. Update `README.md` with the new endpoint
5. Add documentation to `docs/API.md`
6. Test thoroughly

Example structure:
```
src/
├── MyNewFunction/
│   ├── function.json
│   └── run.ps1
└── shared/
```

## Testing Guidelines

### Manual Testing

1. Test locally with `func start --script-root src`
2. Test all endpoints and parameters
3. Test error conditions
4. Verify logging output

### Integration Testing

If adding integration tests:
- Place them in a `tests/` directory
- Use Pester for PowerShell tests
- Ensure they can run in CI/CD

## Documentation Standards

### README Updates

Keep the main README.md:
- Clear and concise
- Up-to-date with current features
- Including all prerequisites
- With working examples

### Code Comments

```powershell
# Good comment - explains WHY
# Cache results to avoid repeated API calls
$cache = @{}

# Bad comment - explains WHAT (obvious from code)
# Create a hashtable
$cache = @{}
```

### Function Documentation

Always include:
- Synopsis
- Description
- Parameters
- Examples
- Return values

## Security Guidelines

- Never commit secrets or credentials
- Use managed identity when possible
- Follow Azure security best practices
- Report security issues privately

## Questions?

- Open an issue for bugs or feature requests
- Use discussions for questions
- Check existing issues before creating new ones

## Recognition

Contributors will be acknowledged in release notes and the project README.

Thank you for contributing!
