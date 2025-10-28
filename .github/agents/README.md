# Custom Copilot Agents

This directory contains custom GitHub Copilot agent configurations for the Azure Health Monitoring Functions project.

## Available Agents

### powershell-azure-expert

**Name:** `powershell-azure-expert`

**Purpose:** A specialized agent for PowerShell Azure Functions development, with expertise in:
- PowerShell 7.4+ scripting and module development
- Azure Functions with PowerShell runtime
- Azure Service Health monitoring
- Azure Resource Graph queries
- Managed Identity and Azure RBAC
- Enterprise-grade serverless architecture

**When to use:**
- Adding new Azure Functions
- Writing or modifying PowerShell scripts
- Working with Azure Resource Graph queries
- Implementing Managed Identity authentication
- Troubleshooting Azure Functions runtime issues
- Creating Pester tests
- Optimizing performance and scalability
- Implementing security best practices

**Key Features:**
- Understands the project structure and conventions
- Follows PowerShell best practices and approved verbs
- Adheres to the project's code style (.PSScriptAnalyzerSettings.psd1, .editorconfig)
- Provides enterprise-ready solutions
- Considers security, scalability, and observability
- Updates documentation alongside code changes

## How to Use Custom Agents

When working with GitHub Copilot in this repository, you can specify the custom agent in your prompts:

### In GitHub Copilot Chat (VS Code, Codespaces, etc.)

```
@powershell-azure-expert help me add a new Azure Function for monitoring Azure VM health
```

### When Assigning Copilot to an Issue

1. Go to the issue you want Copilot to work on
2. Click "Assign Copilot to issue"
3. Select "powershell-azure-expert" from the "Custom agent" dropdown
4. Optionally provide additional context in the "Optional prompt" field
5. Click "Assign"

## Agent Configuration

Custom agents are configured using YAML files in this directory. Each agent configuration includes:

- **name**: Unique identifier for the agent
- **description**: Brief summary of the agent's purpose
- **instructions**: Detailed guidance on how the agent should behave and what it knows about the project
- **tools**: List of tools the agent can use
  - We use `"*"` to grant access to all available tools (read, edit, search, etc.)
  - This is recommended for general-purpose development agents
  - Alternative: Specify individual tools like `["read", "edit", "search"]` for more restricted access

## Customizing Agents

To modify an existing agent or create a new one:

1. Edit the corresponding `.yml` file in this directory
2. Update the `instructions` section to reflect new capabilities or knowledge
3. Commit and push the changes
4. The updated agent will be available immediately (versioned by Git commit SHA)

## Best Practices

- Keep agent instructions focused and relevant to their specific domain
- Include project-specific context (file locations, conventions, tools)
- Reference existing project files and standards
- Provide clear examples of common tasks
- Update agent configurations when project structure or standards change

## Additional Resources

- [GitHub Copilot Custom Agents Documentation](https://docs.github.com/en/copilot/reference/custom-agents-configuration)
- [Project Contributing Guidelines](../../CONTRIBUTING.md)
- [Project Documentation](../../docs/)

## Questions or Issues?

If you encounter issues with custom agents or have suggestions for improvements:
- Open an issue in the repository
- Check the GitHub Copilot documentation
- Review and update the agent configuration as needed
