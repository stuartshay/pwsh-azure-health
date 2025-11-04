# Azure Function Logs

This directory contains scripts for testing and querying Azure Function App logs from Application Insights.

## Prerequisites

⚠️ **Important**: These scripts require the Azure CLI `application-insights` extension. On **first run**, the extension will auto-install, which can take **5+ minutes** with no progress indicator.

### Pre-install the extension (recommended):

```bash
az extension add --name application-insights
```

This one-time setup will prevent the scripts from appearing to hang on first use.

## Scripts

### `query-timer-logs.ps1`
Query GetServiceHealthTimer execution logs from Application Insights with various filtering options.

**Usage:**
```powershell
# Query last 24 hours (default)
./query-timer-logs.ps1

# Query last 48 hours
./query-timer-logs.ps1 -Hours 48

# Show only errors
./query-timer-logs.ps1 -ShowErrors

# Show execution summary
./query-timer-logs.ps1 -ShowSummary

# Production environment
./query-timer-logs.ps1 -Environment prod
```

### `stream-logs.ps1`
Stream real-time logs from the Function App.

**Usage:**
```powershell
# Stream all logs
./stream-logs.ps1

# Stream with filter
./stream-logs.ps1 -Filter "GetServiceHealthTimer"

# Stream from production
./stream-logs.ps1 -Environment prod
```

### `test-logging.ps1`
Manually trigger the timer function to test logging functionality.

**Usage:**
```powershell
# Trigger and view logs
./test-logging.ps1

# Custom wait time
./test-logging.ps1 -WaitSeconds 30

# Test production
./test-logging.ps1 -Environment prod
```

## Application Insights Queries

The scripts use these Kusto (KQL) queries:

### All Timer Logs
```kusto
traces
| where timestamp > ago(24h)
| where cloud_RoleName contains "azurehealth-func"
| where operation_Name == "GetServiceHealthTimer" or message contains "GetServiceHealthTimer"
| order by timestamp desc
| project timestamp, severityLevel, message
```

### Errors Only
```kusto
traces
| where timestamp > ago(24h)
| where cloud_RoleName contains "azurehealth-func"
| where severityLevel >= 3
| where operation_Name == "GetServiceHealthTimer"
| order by timestamp desc
| project timestamp, severityLevel, message
```

### Execution Summary
```kusto
requests
| where timestamp > ago(24h)
| where name == "GetServiceHealthTimer"
| summarize
    Executions = count(),
    Successes = countif(success == true),
    Failures = countif(success == false),
    AvgDurationMs = avg(duration)
```

## Log Severity Levels

- **0** - Verbose (detailed diagnostic information)
- **1** - Information (normal operation messages)
- **2** - Warning (potentially harmful situations)
- **3** - Error (error events that might still allow operation to continue)
- **4** - Critical (severe error events that cause termination)

## Requirements

- Azure CLI installed and authenticated
- Azure CLI `application-insights` extension (see Prerequisites above)
- Access to the Function App resource group
- Application Insights configured for the Function App

## Troubleshooting

### Script hangs for 5+ minutes on first run

This is **normal behavior** when the Azure CLI `application-insights` extension auto-installs. Solutions:

1. **Pre-install the extension** (recommended):
   ```bash
   az extension add --name application-insights
   ```

2. **Wait it out**: The installation only happens once. Subsequent runs will be fast.

3. **Use timeout wrapper** if needed:
   ```powershell
   $job = Start-Job -ScriptBlock { & ./query-timer-logs.ps1 }
   Wait-Job $job -Timeout 600  # 10 minute timeout
   Receive-Job $job
   ```

### "Application Insights component not found"

Ensure Application Insights is deployed:
```bash
az monitor app-insights component list --resource-group rg-azure-health-dev
```

### "No logs found"

1. Verify the timer function has executed (trigger manually):
   ```powershell
   ./test-logging.ps1
   ```

2. Expand the query time range:
   ```powershell
   ./query-timer-logs.ps1 -Hours 48
   ```

3. Verify Application Insights connection in Azure Portal.

## Requirements

- Azure CLI installed and authenticated
- Access to the Function App resource group
- Application Insights configured for the Function App

## Direct Access in Azure Portal

1. **Function Monitor**: Function App → GetServiceHealthTimer → Monitor → Invocations
2. **Log Stream**: Function App → Log stream
3. **Application Insights**: Application Insights → Logs → Run queries above
4. **Live Metrics**: Application Insights → Live Metrics
