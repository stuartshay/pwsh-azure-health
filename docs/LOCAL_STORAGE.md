# Local Azure Storage with Azurite

This project uses [Azurite](https://github.com/Azure/Azurite) to emulate Azure Storage services locally for development and testing.

## What is Azurite?

Azurite is an open-source Azure Storage emulator that provides:
- **Blob Storage** (port 10000)
- **Queue Storage** (port 10001)
- **Table Storage** (port 10002)

It allows you to develop and test Azure Functions locally without connecting to a real Azure Storage account.

## Automatic Setup

Azurite is automatically configured when you build the DevContainer:

1. **Installation**: Azurite is installed via npm during the post-create phase
2. **Auto-Start**: Azurite starts automatically in the background
3. **Data Directory**: Data is stored in `~/.azurite`
4. **Ports**: The following ports are forwarded:
   - 10000 - Blob Service
   - 10001 - Queue Service
   - 10002 - Table Service

## Connection String

The Azure Functions project is pre-configured with the Azurite connection string in `src/local.settings.json`:

```json
{
  "Values": {
    "AzureWebJobsStorage": "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;"
  }
}
```

## Manual Management

### Check if Azurite is Running

```bash
ps aux | grep azurite
```

### View Azurite Logs

```bash
cat ~/.azurite/debug.log
```

### Start Azurite Manually

If Azurite isn't running, you can start it manually:

```bash
./scripts/local/start-azurite.sh
```

Or directly:

```bash
azurite --silent --location ~/.azurite --debug ~/.azurite/debug.log \
  --blobHost 0.0.0.0 --queueHost 0.0.0.0 --tableHost 0.0.0.0 &
```

### Stop Azurite

```bash
pkill -f azurite
```

### Clear Azurite Data

To reset all local storage data:

```bash
pkill -f azurite
rm -rf ~/.azurite
mkdir -p ~/.azurite
./scripts/local/start-azurite.sh
```

## Verify Connectivity

### Test Blob Service

```bash
curl http://127.0.0.1:10000/devstoreaccount1?comp=list
```

Expected response: An XML list of containers (empty initially).

### Test with Azure Storage Explorer

You can connect [Azure Storage Explorer](https://azure.microsoft.com/en-us/products/storage/storage-explorer/) to Azurite:

1. Open Azure Storage Explorer
2. Select "Attach to a local emulator"
3. Use these settings:
   - **Display name**: Local Azurite
   - **Blob endpoint**: http://127.0.0.1:10000
   - **Queue endpoint**: http://127.0.0.1:10001
   - **Table endpoint**: http://127.0.0.1:10002
   - **Account name**: devstoreaccount1
   - **Account key**: `Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==`

## Troubleshooting

### "Connection refused" errors

If you get connection errors, verify Azurite is running:

```bash
# Check process
ps aux | grep azurite

# Check ports
netstat -tlnp | grep -E '10000|10001|10002'

# Restart if needed
pkill -f azurite
./scripts/local/start-azurite.sh
```

### Port conflicts

If ports 10000-10002 are already in use:

```bash
# Find what's using the ports
lsof -i :10000
lsof -i :10001
lsof -i :10002

# Kill conflicting processes or change Azurite ports in:
# - .devcontainer/post-create.sh
# - scripts/local/start-azurite.sh
# - src/local.settings.json
```

### Azure Functions can't connect

If Functions can't connect to Azurite:

1. Verify Azurite is running
2. Check the connection string in `src/local.settings.json`
3. Ensure ports are forwarded in `.devcontainer/devcontainer.json`
4. Restart the Functions host: `cd src && func start`

## Using in Tests

You can use Azurite in your Pester tests:

```powershell
BeforeAll {
    # Import required modules
    Import-Module Az.Storage

    # Connect to Azurite
    $context = New-AzStorageContext -ConnectionString "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;"

    # Create test container
    New-AzStorageContainer -Name "test-container" -Context $context -ErrorAction SilentlyContinue
}

Describe "Storage Tests" {
    It "Can upload a blob" {
        $blob = Set-AzStorageBlobContent -File "test.txt" -Container "test-container" -Blob "test.txt" -Context $context
        $blob | Should -Not -BeNullOrEmpty
    }
}

AfterAll {
    # Cleanup
    Remove-AzStorageContainer -Name "test-container" -Context $context -Force -ErrorAction SilentlyContinue
}
```

## Resources

- [Azurite Documentation](https://github.com/Azure/Azurite)
- [Azure Storage Emulator vs Azurite](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azurite)
- [Azure Functions Local Storage](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local#local-settings-file)
