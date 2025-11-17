---
version: 1.0.0
last-updated: 2025-11-17
---

# API Documentation

This document provides detailed information about the Azure Health Monitoring Functions API endpoints.

## Base URL

- **Local Development:** `http://localhost:7071/api`
- **Azure Deployment:** `https://[your-function-app].azurewebsites.net/api`

## Authentication

All endpoints require function-level authentication. Include the function key in one of the following ways:

1. **Query Parameter:**
   ```
   ?code=[function-key]
   ```

2. **Header:**
   ```
   x-functions-key: [function-key]
   ```

## Endpoints

### Get Service Health

Retrieves Azure Service Health events for a specified subscription.

#### Endpoint
```
GET|POST /api/GetServiceHealth
```

#### Parameters

| Name | Type | Location | Required | Description |
|------|------|----------|----------|-------------|
| SubscriptionId | string | Query/Body | No* | Azure subscription ID to query. If not provided, uses `AZURE_SUBSCRIPTION_ID` environment variable. |
| code | string | Query | Yes** | Function authorization key |

\* Required if `AZURE_SUBSCRIPTION_ID` is not configured in application settings  
\** Required when deployed to Azure (not needed for local development)

#### Request Examples

**GET Request:**
```bash
curl "http://localhost:7071/api/GetServiceHealth?SubscriptionId=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

**GET Request with Authorization (Azure):**
```bash
curl "https://[your-function-app-name].azurewebsites.net/api/GetServiceHealth?code=your-function-key&SubscriptionId=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

**POST Request with JSON Body:**
```bash
curl -X POST http://localhost:7071/api/GetServiceHealth \
  -H "Content-Type: application/json" \
  -d '{"SubscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"}'
```

**PowerShell Example:**
```powershell
$params = @{
    Uri    = "http://localhost:7071/api/GetServiceHealth"
    Method = "POST"
    Body   = @{
        SubscriptionId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    } | ConvertTo-Json
    ContentType = "application/json"
}
Invoke-RestMethod @params
```

#### Response

**Success Response (200 OK):**
```json
{
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "retrievedAt": "2025-10-28T17:23:45.1234567Z",
  "eventCount": 2,
  "events": [
    {
      "id": "/subscriptions/xxx/providers/Microsoft.ResourceHealth/events/xxx",
      "eventType": "ServiceIssue",
      "status": "Active",
      "title": "Azure Virtual Machines - East US",
      "summary": "We are investigating an issue affecting Azure Virtual Machines in East US region",
      "level": "Warning",
      "impactedServices": [
        {
          "ImpactedRegions": [
            {
              "RegionName": "East US"
            }
          ],
          "ServiceName": "Virtual Machines"
        }
      ],
      "lastUpdateTime": "2025-10-28T15:30:00Z"
    },
    {
      "id": "/subscriptions/xxx/providers/Microsoft.ResourceHealth/events/xxx",
      "eventType": "PlannedMaintenance",
      "status": "Active",
      "title": "Planned Maintenance - Azure SQL Database",
      "summary": "Scheduled maintenance for Azure SQL Database infrastructure",
      "level": "Informational",
      "impactedServices": [
        {
          "ImpactedRegions": [
            {
              "RegionName": "West US 2"
            }
          ],
          "ServiceName": "SQL Database"
        }
      ],
      "lastUpdateTime": "2025-10-27T10:00:00Z"
    }
  ]
}
```

**Error Response - Missing Subscription ID (400 Bad Request):**
```json
{
  "error": "Please pass a SubscriptionId on the query string or in the request body, or configure AZURE_SUBSCRIPTION_ID in application settings."
}
```

**Error Response - Internal Error (500 Internal Server Error):**
```json
{
  "error": "An error occurred while retrieving Azure Service Health data.",
  "details": "Detailed error message here"
}
```

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| subscriptionId | string | The Azure subscription ID that was queried |
| retrievedAt | string | ISO 8601 timestamp when the data was retrieved |
| eventCount | integer | Number of service health events returned |
| events | array | Array of service health event objects |

#### Event Object Fields

| Field | Type | Description |
|-------|------|-------------|
| id | string | Unique identifier for the event |
| eventType | string | Type of event: "ServiceIssue" or "PlannedMaintenance" |
| status | string | Current status: "Active" or "Resolved" |
| title | string | Brief title describing the event |
| summary | string | Detailed description of the event |
| level | string | Severity level: "Critical", "Error", "Warning", or "Informational" |
| impactedServices | array | List of affected Azure services and regions |
| lastUpdateTime | string | ISO 8601 timestamp of the last update |

#### Event Types

- **ServiceIssue:** Unplanned service disruptions or degradations
- **PlannedMaintenance:** Scheduled maintenance activities
- **HealthAdvisory:** Health advisories and recommendations
- **Security:** Security-related notifications

#### Status Values

- **Active:** The event is currently active
- **Resolved:** The event has been resolved

#### Level Values

- **Critical:** Critical impact, immediate action required
- **Error:** Significant impact, action required
- **Warning:** Moderate impact, attention needed
- **Informational:** No immediate impact, informational only

## Query Time Range

By default, the API returns events from the last 7 days. This includes:
- All currently active events
- Events that were updated within the last 7 days

## Rate Limiting

The Azure Functions Consumption Plan has the following limits:
- **Requests per second:** Limited by Azure Functions scale-out capabilities
- **Timeout:** 10 minutes (configurable in `host.json`)

For production use, consider:
- Implementing client-side caching
- Using appropriate retry logic
- Monitoring Application Insights for throttling

## Error Codes

| Status Code | Description |
|-------------|-------------|
| 200 | Success |
| 400 | Bad Request - Missing required parameters |
| 401 | Unauthorized - Invalid or missing function key |
| 403 | Forbidden - Insufficient permissions |
| 500 | Internal Server Error - Server-side error |
| 503 | Service Unavailable - Function app is unavailable |

## Best Practices

### 1. Caching
```javascript
// Example: Cache results for 5 minutes
const CACHE_DURATION = 5 * 60 * 1000;
let cachedData = null;
let cacheTimestamp = 0;

function getServiceHealth() {
  const now = Date.now();
  if (cachedData && (now - cacheTimestamp) < CACHE_DURATION) {
    return cachedData;
  }

  // Fetch new data
  const data = await fetch('/api/GetServiceHealth?...');
  cachedData = data;
  cacheTimestamp = now;
  return data;
}
```

### 2. Error Handling
```javascript
async function getServiceHealth() {
  try {
    const response = await fetch('/api/GetServiceHealth?...');
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    console.error('Failed to fetch service health:', error);
    // Handle error appropriately
  }
}
```

### 3. Polling
```javascript
// Poll every 5 minutes
setInterval(async () => {
  const healthData = await getServiceHealth();
  updateUI(healthData);
}, 5 * 60 * 1000);
```

## Extending the API

To add new endpoints:

1. Create a new function directory
2. Add `function.json` with bindings
3. Implement the function in `run.ps1`
4. Update this documentation
5. Test thoroughly

Example template:
```powershell
using namespace System.Net

param($Request, $TriggerMetadata)

# Your logic here

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = @{
        message = "Success"
    }
})
```

## Support

For issues or questions about the API:
- Check the [troubleshooting guide](SETUP.md#troubleshooting)
- Review Application Insights logs
- Open an issue on GitHub
