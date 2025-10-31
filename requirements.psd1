# PowerShell module dependencies for the Azure Health Monitoring project
# This is the master dependency list used by:
# - DevContainer setup (.devcontainer/post-create.sh)
# - CI/CD pipelines
# - Local development
#
# Note: src/requirements.psd1 contains a minimal subset for Azure Functions runtime
# See https://docs.microsoft.com/en-us/powershell/module/powershellget/install-module
#
@{
    # Core Azure modules (required for runtime and development)
    'Az.Accounts'       = @{ Version = '3.*' }
    'Az.Storage'        = @{ Version = '7.*' }
    'Az.ResourceGraph'  = @{ Version = '1.*' }

    # Additional Azure modules for development and infrastructure
    'Az.Resources'      = @{ Version = '7.*' }
    'Az.Monitor'        = @{ Version = '5.*' }
    'Az.Functions'      = @{ Version = '4.*' }
    'Az.Websites'       = @{ Version = '3.*' }

    # Testing and code quality modules
    'Pester'            = @{ Version = '5.*'; MaximumVersion = '5.99.99' }
    'PSScriptAnalyzer'  = @{ Version = '1.*' }

    # Optional: Helpful development modules
    # 'PowerShellGet'   = @{ Version = '3.*' }
}
