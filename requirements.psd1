# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanageddependency for additional information.
#
@{
    # For latest supported version, go to 'https://www.powershellgallery.com/packages/Az'.
    # To use the Az module in your function app, please uncomment the line below.
    'Az' = '12.*'
    
    # Azure Resource Graph module for querying Azure resources
    'Az.ResourceGraph' = '1.*'
    
    # Azure Monitor module for health data
    'Az.Monitor' = '5.*'
}
