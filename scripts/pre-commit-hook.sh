#!/usr/bin/env bash
# Pre-commit validation script for Azure Health Monitoring Functions
# This script runs all quality checks before allowing a commit

set -e

echo "🔍 Running pre-commit checks..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

# Function to print colored messages
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        FAILED=1
    fi
}

# Check for large files
echo ""
echo "📏 Checking for large files..."
if git diff --cached --name-only | xargs -I {} find {} -type f -size +500k 2>/dev/null | grep -q .; then
    echo -e "${RED}✗${NC} Large files detected (>500KB). Please remove or use Git LFS."
    git diff --cached --name-only | xargs -I {} find {} -type f -size +500k 2>/dev/null
    FAILED=1
else
    echo -e "${GREEN}✓${NC} No large files detected"
fi

# Check for merge conflict markers
echo ""
echo "🔀 Checking for merge conflict markers..."
if git diff --cached | grep -E "^(\+<<<<<<< |^\+=======$|^\+>>>>>>> )" > /dev/null; then
    echo -e "${RED}✗${NC} Merge conflict markers detected"
    FAILED=1
else
    echo -e "${GREEN}✓${NC} No merge conflict markers"
fi

# Check YAML files
echo ""
echo "📋 Validating YAML files..."
YAML_VALID=0
for file in $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(yml|yaml)$'); do
    if [ -f "$file" ]; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            echo -e "${RED}✗${NC} Invalid YAML: $file"
            YAML_VALID=1
        fi
    fi
done
print_status $YAML_VALID "YAML validation"

# Check JSON files
echo ""
echo "📋 Validating JSON files..."
JSON_VALID=0
for file in $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.json$'); do
    if [ -f "$file" ]; then
        if ! python3 -m json.tool "$file" > /dev/null 2>&1; then
            echo -e "${RED}✗${NC} Invalid JSON: $file"
            JSON_VALID=1
        fi
    fi
done
print_status $JSON_VALID "JSON validation"

# Check Bicep files
echo ""
echo "🔧 Validating Bicep files..."
BICEP_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.bicep$' || true)
BICEP_VALID=0
if [ ! -z "$BICEP_FILES" ]; then
    if command -v az > /dev/null 2>&1; then
        for file in $BICEP_FILES; do
            if [ -f "$file" ]; then
                echo "  Validating $file..."
                if ! az bicep build --file "$file" --stdout > /dev/null 2>&1; then
                    echo -e "${RED}✗${NC} Invalid Bicep: $file"
                    BICEP_VALID=1
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠${NC} Azure CLI not installed, skipping Bicep validation"
    fi
fi
print_status $BICEP_VALID "Bicep validation"

# Check GitHub Actions workflow files
echo ""
echo "⚙️  Validating GitHub Actions workflows..."
WORKFLOW_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^\.github/workflows/.*\.yml$' || true)
WORKFLOW_VALID=0
if [ ! -z "$WORKFLOW_FILES" ]; then
    if command -v actionlint > /dev/null 2>&1; then
        for file in $WORKFLOW_FILES; do
            if [ -f "$file" ]; then
                echo "  Validating $file..."
                if ! actionlint "$file" 2>&1; then
                    echo -e "${RED}✗${NC} Invalid workflow: $file"
                    WORKFLOW_VALID=1
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠${NC} actionlint not installed, skipping workflow validation"
    fi
fi
print_status $WORKFLOW_VALID "GitHub Actions validation"

# Check for trailing whitespace and fix it
echo ""
echo "🧹 Checking for trailing whitespace..."
WHITESPACE_FILES=$(git diff --cached --name-only --diff-filter=ACM | xargs -I {} grep -l ' $' {} 2>/dev/null || true)
if [ ! -z "$WHITESPACE_FILES" ]; then
    echo -e "${YELLOW}⚠${NC} Trailing whitespace found in:"
    echo "$WHITESPACE_FILES"
    echo "Attempting to fix..."
    echo "$WHITESPACE_FILES" | xargs sed -i 's/[[:space:]]*$//'
    echo "$WHITESPACE_FILES" | xargs git add
    echo -e "${GREEN}✓${NC} Fixed trailing whitespace"
else
    echo -e "${GREEN}✓${NC} No trailing whitespace"
fi

# Check PowerShell files with PSScriptAnalyzer
echo ""
echo "🔍 Running PSScriptAnalyzer..."
PS_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ps1|psm1|psd1)$' || true)
if [ ! -z "$PS_FILES" ]; then
    if command -v pwsh > /dev/null 2>&1; then
        if ! pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./.PSScriptAnalyzerSettings.psd1 -ReportSummary -EnableExit" 2>&1; then
            echo -e "${RED}✗${NC} PSScriptAnalyzer found issues"
            FAILED=1
        else
            echo -e "${GREEN}✓${NC} PSScriptAnalyzer passed"
        fi
    else
        echo -e "${YELLOW}⚠${NC} PowerShell not installed, skipping PSScriptAnalyzer"
    fi
else
    echo -e "${GREEN}✓${NC} No PowerShell files to check"
fi

# Check for secrets in common patterns
echo ""
echo "🔒 Checking for potential secrets..."
SECRET_PATTERNS=(
    "password\s*=\s*['\"].*['\"]"
    "api[_-]?key\s*=\s*['\"].*['\"]"
    "secret\s*=\s*['\"].*['\"]"
    "token\s*=\s*['\"].*['\"]"
    "private[_-]?key"
    "BEGIN RSA PRIVATE KEY"
    "BEGIN PRIVATE KEY"
)

SECRET_FOUND=0
for pattern in "${SECRET_PATTERNS[@]}"; do
    if git diff --cached | grep -iE "$pattern" > /dev/null 2>&1; then
        echo -e "${RED}✗${NC} Potential secret detected matching pattern: $pattern"
        SECRET_FOUND=1
    fi
done
if [ $SECRET_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No secrets detected"
else
    FAILED=1
fi

# Summary
echo ""
echo "================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All pre-commit checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Pre-commit checks failed${NC}"
    echo "Please fix the issues above and try committing again."
    exit 1
fi
