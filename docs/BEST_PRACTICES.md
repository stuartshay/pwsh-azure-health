# Best Practices for Azure Health Monitoring Functions

This document outlines best practices for developing, deploying, and maintaining Azure Functions using PowerShell.

## Code Quality

### PowerShell Scripting

1. **Use Approved Verbs**
   ```powershell
   # Good
   Get-ServiceHealth
   Set-AlertConfiguration
   
   # Bad
   Fetch-ServiceHealth
   Change-AlertConfiguration
   ```

2. **Error Handling**
   ```powershell
   try {
       $result = Get-AzResource -ErrorAction Stop
   }
   catch {
       Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
       # Log to Application Insights
       throw
   }
   ```

3. **Input Validation**
   ```powershell
   param(
       [Parameter(Mandatory = $true)]
       [ValidateNotNullOrEmpty()]
       [string]$SubscriptionId,
       
       [ValidateRange(1, 90)]
       [int]$DaysBack = 7
   )
   ```

4. **Logging**
   ```powershell
   # Use Write-Information for structured logging in Azure Functions
   Write-Information "Processing request" -InformationAction Continue
   Write-Information "SubscriptionId: $subscriptionId" -InformationAction Continue
   Write-Information "DaysBack: $daysBack" -InformationAction Continue
   
   # Include timing information
   $startTime = Get-Date
   # ... processing ...
   $duration = (Get-Date) - $startTime
   Write-Information "Completed in $($duration.TotalSeconds) seconds" -InformationAction Continue
   ```

### Code Organization

1. **Modular Functions**
   - Keep functions small and focused
   - Extract reusable code into helper functions
   - Use profile.ps1 for shared utilities

2. **Configuration Management**
   - Use environment variables for configuration
   - Never hardcode secrets or credentials
   - Use Azure Key Vault for sensitive data
   - Store reusable modules under `src/shared/Modules` and scripts under `src/shared/Scripts`

3. **Documentation**
   - Include comment-based help for all functions
   - Document complex business logic
   - Keep README up to date

## Performance

### Optimization

1. **Managed Dependencies**
   ```powershell
   # requirements.psd1
   @{
       'Az' = '12.*'  # Use version ranges for flexibility
   }
   ```

2. **Caching**
   - Cache results when appropriate
   - Use Azure Redis Cache for distributed caching
   - Implement cache invalidation strategies

3. **Parallel Processing**
   ```powershell
   # Process multiple subscriptions in parallel
   $subscriptions | ForEach-Object -Parallel {
       Get-ServiceHealth -SubscriptionId $_.Id
   } -ThrottleLimit 5
   ```

4. **Query Optimization**
   - Use Resource Graph for efficient querying
   - Filter data at the source
   - Limit result sets appropriately

### Resource Management

1. **Connection Pooling**
   - Reuse Azure connections when possible
   - Avoid creating new contexts unnecessarily

2. **Memory Management**
   - Dispose of large objects promptly
   - Use streaming for large datasets
   - Monitor memory usage in Application Insights

## Security

### Authentication & Authorization

1. **Managed Identity**
   ```powershell
   # profile.ps1
   if ($env:MSI_SECRET) {
       Connect-AzAccount -Identity
   }
   ```

2. **Function Keys**
   - Use function-level authentication
   - Rotate keys regularly
   - Use different keys for different environments

3. **RBAC**
   - Grant least privilege access
   - Use Azure AD groups for role assignments
   - Document required permissions

### Data Protection

1. **Sensitive Data**
   - Never log sensitive information
   - Use Azure Key Vault for secrets
   - Encrypt data at rest and in transit

2. **Input Sanitization**
   ```powershell
   # Validate and sanitize inputs
   if ($input -match '^[a-zA-Z0-9-]+$') {
       # Process
   } else {
       throw "Invalid input format"
   }
   ```

## Deployment

### CI/CD

1. **Automated Testing**
   - Write Pester tests for PowerShell code
   - Test functions locally before deployment
   - Use staging slots for validation

2. **Version Control**
   - Use semantic versioning
   - Tag releases appropriately
   - Maintain a changelog

3. **Infrastructure as Code**
   ```powershell
   # Use ARM templates or Bicep
   az deployment group create \
     --resource-group rg-azure-health \
     --template-file infrastructure/main.bicep
   ```

### Configuration

1. **Environment Separation**
   - Maintain separate configurations for dev/test/prod
   - Use different resource groups per environment
   - Implement environment-specific settings

2. **Application Settings**
   ```bash
   # Use Azure CLI or ARM templates
   az functionapp config appsettings set \
     --name func-azure-health \
     --settings "SETTING_NAME=value"
   ```

## Monitoring & Observability

### Application Insights

1. **Custom Metrics**
   ```powershell
   # Track custom metrics
   $telemetry = @{
       name = "ServiceHealthCheck"
       properties = @{
           subscriptionId = $subscriptionId
           eventCount = $events.Count
       }
   }
   # Log to Application Insights
   ```

2. **Alerts**
   - Set up alerts for failures
   - Monitor function execution time
   - Track error rates

3. **Dashboards**
   - Create Azure Dashboard for key metrics
   - Use workbooks for detailed analysis
   - Share dashboards with stakeholders

### Logging

1. **Structured Logging**
   ```powershell
   # Use PowerShell objects for structured logging
   $logData = @{
       timestamp = Get-Date -Format 'o'
       level = "Information"
       message = "Processing completed"
       subscriptionId = $subscriptionId
       eventCount = $count
   }
   Write-Information ($logData | ConvertTo-Json -Compress) -InformationAction Continue
   ```

2. **Log Levels**
   - Use appropriate log levels (Error, Warning, Info, Debug)
   - Avoid excessive logging in production
   - Include context in error messages

## Scalability

### Design Patterns

1. **Stateless Functions**
   - Keep functions stateless when possible
   - Store state in external storage if needed
   - Design for horizontal scaling

2. **Queue-Based Processing**
   ```powershell
   # Use queue triggers for background processing
   param($QueueItem, $TriggerMetadata)
   
   # Process queue message
   Process-ServiceHealthEvent -Event $QueueItem
   ```

3. **Fan-Out/Fan-In**
   - Use durable functions for complex workflows
   - Implement retries and circuit breakers
   - Handle partial failures gracefully

### Resource Planning

1. **Consumption Plan**
   - Good for variable workloads
   - Auto-scaling based on demand
   - Cost-effective for low-volume scenarios

2. **Premium Plan**
   - Use for predictable, high-volume workloads
   - Provides VNet integration
   - Better cold start performance

## Testing

### Unit Testing

```powershell
# Use Pester for testing
Describe "Get-ServiceHealth" {
    It "Should return events for valid subscription" {
        $result = Get-ServiceHealth -SubscriptionId "test-id"
        $result | Should -Not -BeNullOrEmpty
    }
    
    It "Should throw error for invalid subscription" {
        { Get-ServiceHealth -SubscriptionId "" } | Should -Throw
    }
}
```

### Integration Testing

1. **Local Testing**
   - Test with realistic data
   - Verify error handling
   - Check performance

2. **Staging Environment**
   - Deploy to staging before production
   - Run smoke tests
   - Validate monitoring

## Maintenance

### Regular Tasks

1. **Dependency Updates**
   ```powershell
   # Update PowerShell modules regularly
   Update-Module Az
   Update-Module Az.ResourceGraph
   ```

2. **Performance Monitoring**
   - Review Application Insights metrics weekly
   - Identify and fix bottlenecks
   - Optimize slow queries

3. **Security Updates**
   - Apply security patches promptly
   - Review and update dependencies
   - Scan for vulnerabilities

### Documentation

1. **Code Comments**
   - Comment complex logic
   - Explain business rules
   - Document assumptions

2. **Architecture Decisions**
   - Document major design decisions
   - Maintain ADR (Architecture Decision Records)
   - Update diagrams as needed

3. **Runbooks**
   - Create operational runbooks
   - Document troubleshooting steps
   - Maintain contact information

## Cost Optimization

1. **Resource Cleanup**
   - Remove unused resources
   - Stop non-production resources when not needed
   - Use Azure Advisor recommendations

2. **Efficient Queries**
   - Minimize data transfer
   - Use appropriate time ranges
   - Cache frequently accessed data

3. **Monitoring**
   - Track function execution costs
   - Monitor storage costs
   - Review Application Insights usage

## Disaster Recovery

1. **Backup Strategy**
   - Export function app configuration
   - Store code in version control
   - Document recovery procedures

2. **High Availability**
   - Deploy to multiple regions if needed
   - Use Traffic Manager for failover
   - Implement health checks

3. **Business Continuity**
   - Define RTO and RPO
   - Test recovery procedures
   - Document dependencies

## References

- [Azure Functions Best Practices](https://docs.microsoft.com/en-us/azure/azure-functions/functions-best-practices)
- [PowerShell Best Practices](https://poshcode.gitbooks.io/powershell-practice-and-style/)
- [Azure Architecture Center](https://docs.microsoft.com/en-us/azure/architecture/)
