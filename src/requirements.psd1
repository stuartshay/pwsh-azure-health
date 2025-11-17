# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanageddependency for additional information.
#
# NOTE: This is a MINIMAL subset for Azure Functions runtime only.
# For the full development dependency list, see /requirements.psd1 in the repo root.
#
@{
    # Minimal module set for Service Health polling and storage access
    # Pinned to specific versions for reproducible builds
    # These versions are tested and verified to work with Azure Functions runtime
    'Az.Accounts'      = '5.3.0'
    'Az.Storage'       = '9.3.0'
    'Az.ResourceGraph' = '1.2.1'
}
