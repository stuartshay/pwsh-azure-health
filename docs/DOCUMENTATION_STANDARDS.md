---
version: 1.0.0
last-updated: 2025-11-17
---

# Documentation Standards

This document defines the standards and conventions for maintaining documentation in this project.

## Document Versioning

All documentation files must include YAML front matter with version metadata at the top of the file:

```yaml
---
version: 1.0.0
last-updated: 2025-11-17
---
```

### Version Format

Use **Semantic Versioning** (major.minor.patch):

- **Major version** (X.0.0): Significant restructuring, architectural changes, or complete rewrites
  - Example: Changing from System-Assigned to User-Assigned Managed Identity
  - Example: Complete reorganization of document structure

- **Minor version** (x.Y.0): Content updates, additions, or corrections that don't change the core structure
  - Example: Adding new sections or procedures
  - Example: Updating version numbers or configuration examples
  - Example: Clarifying existing content

- **Patch version** (x.y.Z): Typo fixes, formatting improvements, or minor clarifications
  - Example: Fixing typos or grammar
  - Example: Correcting formatting issues
  - Example: Minor wording improvements

### Date Format

Use **ISO 8601 format** (YYYY-MM-DD) for the `last-updated` field:

```yaml
last-updated: 2025-11-17
```

### When to Update Version

Update the version and date whenever you make changes to a document:

1. **Making changes:** Increment the appropriate version number (major, minor, or patch)
2. **Update date:** Always update `last-updated` to the current date
3. **Document changes:** Consider adding a changelog section for major/minor version updates

### Optional Metadata Fields

You may include additional metadata fields as needed:

```yaml
---
version: 1.0.0
last-updated: 2025-11-17
author: Your Name
review-cycle: quarterly
status: active
classification: public
---
```

## Markdown Formatting

### Line Breaks

Use **two trailing spaces** for explicit line breaks in markdown:

```markdown
This is a line.  
This is the next line.
```

The `.pre-commit-config.yaml` is configured to preserve two-space line breaks in markdown files.

### Code Blocks

Use fenced code blocks with language identifiers:

````markdown
```powershell
Get-AzResourceHealth
```
````

### Headings

- Use ATX-style headings (`#`, `##`, `###`)
- Include a space after the `#` symbols
- Use Title Case for document titles (H1)
- Use Sentence case for section headings (H2-H6)

### Links

Use descriptive link text:

```markdown
✅ Good: See the [Deployment Guide](DEPLOYMENT.md) for details.
❌ Bad: Click [here](DEPLOYMENT.md) for details.
```

### Lists

- Use `-` for unordered lists
- Use `1.` for ordered lists (numbers will auto-increment)
- Indent nested lists with 2 spaces

## File Organization

### Naming Conventions

- Use **UPPERCASE** for documentation files (e.g., `README.md`, `SETUP.md`)
- Use **kebab-case** for scripts and code files (e.g., `deploy-bicep.ps1`)
- Use descriptive names that clearly indicate the content

### Document Structure

Standard documentation structure:

```markdown
---
version: 1.0.0
last-updated: 2025-11-17
---

# Document Title

Brief overview of what this document covers.

## Section 1

Content...

## Section 2

Content...

## Related Documents

- [Document Name](PATH.md)
```

### Cross-References

Link to related documents at the end of each file:

```markdown
## Related Documents

- [Deployment Guide](DEPLOYMENT.md)
- [Security & Permissions](SECURITY_PERMISSIONS.md)
- [API Documentation](API.md)
```

## Quality Checks

### Pre-commit Hooks

The project uses pre-commit hooks to enforce quality standards:

- **markdownlint:** Ensures markdown formatting consistency
- **trailing-whitespace:** Preserves two-space line breaks in markdown files
- **end-of-file-fixer:** Ensures files end with a newline
- **mixed-line-ending:** Enforces consistent line endings

### Manual Review Checklist

Before committing documentation changes:

- [ ] Updated version number appropriately
- [ ] Updated `last-updated` date
- [ ] Checked for broken links
- [ ] Verified code examples are accurate
- [ ] Ensured consistent formatting
- [ ] Reviewed for typos and grammar
- [ ] Added cross-references to related documents

## Documentation Types

### README.md

- **Purpose:** Project overview and getting started guide
- **Audience:** New users and contributors
- **Version:** Major updates for architectural changes

### Technical Guides

Files like `DEPLOYMENT.md`, `SETUP.md`, `API.md`:

- **Purpose:** Step-by-step procedures and reference information
- **Audience:** Developers and operators
- **Version:** Minor updates for procedure changes or additions

### Reference Documentation

Files like `SECURITY_PERMISSIONS.md`, `BEST_PRACTICES.md`:

- **Purpose:** In-depth technical reference and guidelines
- **Audience:** Advanced users and maintainers
- **Version:** Major updates for architectural changes, minor for additions

## Review Cycle

Documentation should be reviewed periodically to ensure accuracy:

- **Critical docs** (README, DEPLOYMENT, SECURITY): Review quarterly
- **Technical guides** (SETUP, API): Review semi-annually
- **Reference docs** (BEST_PRACTICES, CODE_QUALITY): Review annually

Mark documents for review by adding an optional metadata field:

```yaml
---
version: 1.0.0
last-updated: 2025-11-17
next-review: 2026-02-17
---
```

## Related Documents

- [Contributing Guide](../CONTRIBUTING.md)
- [Next Steps & Improvements](NEXT_STEPS.md)
- [Code Quality Standards](CODE_QUALITY.md)
