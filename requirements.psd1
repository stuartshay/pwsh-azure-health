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
    # Pinned to specific versions for reproducible builds
    'Az.Accounts'        = '5.3.0'
    'Az.Storage'         = '9.3.0'
    'Az.ResourceGraph'   = '1.2.1'

    # Additional Azure modules for development and infrastructure
    'Az.Resources'       = '8.1.1'
    'Az.Monitor'         = '6.0.3'
    'Az.Functions'       = '4.2.1'
    'Az.Websites'        = '3.4.2'

    # Testing and code quality modules
    'Pester'             = '5.7.1'
    'PSScriptAnalyzer'   = '1.24.0'
    'PSRule'             = '2.9.0'
    'PSRule.Rules.Azure' = '1.39.1'

    # Optional: Helpful development modules
    # 'PowerShellGet'   = @{ Version = '3.*' }
}
