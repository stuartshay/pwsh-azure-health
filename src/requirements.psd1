# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanageddependency for additional information.
#
@{
    # Minimal module set for Service Health polling and storage access
    'Az.Accounts'      = '3.*'
    'Az.Storage'       = '5.*'
    'Az.ResourceGraph' = '1.*'
}
