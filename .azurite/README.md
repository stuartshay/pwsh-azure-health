# Azurite Local Storage Directory

This directory contains local Azure Storage emulation data for development.

## Contents

When Azurite is running, this directory will contain:

- `__blobstorage__/` - Blob storage data
- `__queuestorage__/` - Queue storage data
- `__azurite_db_blob__.json` - Blob service metadata
- `__azurite_db_queue__.json` - Queue service metadata
- `__azurite_db_table__.json` - Table service metadata
- `debug.log` - Azurite debug logs

## Important Notes

- **This directory is git-ignored** - State files should not be committed
- **Only this README is tracked in git** - To document the directory structure
- **Data is local only** - Not shared between developers or environments
- **Can be safely deleted** - All state will be recreated when Azurite starts

## Resetting Local Storage

To clear all local storage data:

```bash
# Stop Azurite
pkill -f azurite

# Clear the directory (keeps README)
find .azurite -mindepth 1 ! -name 'README.md' -delete

# Restart Azurite
./scripts/local/start-azurite.sh
```

## See Also

- [docs/LOCAL_STORAGE.md](../docs/LOCAL_STORAGE.md) - Complete Azurite documentation
- [scripts/local/start-azurite.sh](../scripts/local/start-azurite.sh) - Start script
