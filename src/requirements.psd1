# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanageddependency for additional information.
#
# NOTE: This is a MINIMAL subset for Azure Functions runtime only.
# For the full development dependency list, see /requirements.psd1 in the repo root.
#
@{
    # Minimal module set for Service Health polling and storage access
    'Az.Accounts'      = '3.*'
    'Az.Storage'       = '5.*'
    'Az.ResourceGraph' = '1.*'
}
