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
    'Az.Accounts'       = @{ MinimumVersion = '3.0.0' }
    'Az.Storage'        = @{ MinimumVersion = '7.0.0' }
    'Az.ResourceGraph'  = @{ MinimumVersion = '1.0.0' }

    # Additional Azure modules for development and infrastructure
    'Az.Resources'      = @{ MinimumVersion = '7.0.0' }
    'Az.Monitor'        = @{ MinimumVersion = '5.0.0' }
    'Az.Functions'      = @{ MinimumVersion = '4.0.0' }
    'Az.Websites'       = @{ MinimumVersion = '3.0.0' }

    # Testing and code quality modules
    'Pester'            = @{ MinimumVersion = '5.0.0'; MaximumVersion = '5.99.99' }
    'PSScriptAnalyzer'  = @{ MinimumVersion = '1.23.0'; MaximumVersion = '1.99.99' }
    'PSRule'            = @{ MinimumVersion = '2.0.0' }
    'PSRule.Rules.Azure' = @{ MinimumVersion = '1.0.0' }

    # Optional: Helpful development modules
    # 'PowerShellGet'   = @{ Version = '3.*' }
}
