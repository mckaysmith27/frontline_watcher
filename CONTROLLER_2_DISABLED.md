# Controller 2 Disabled

## Status: ✅ Controller 2 is DISABLED

**Only Controller 1 should be running.**

## Current Configuration

- ✅ **Controller 1**: Enabled (will run when EC2 starts)
- 🛑 **Controller 2**: DISABLED (will NOT run)

## When EC2 Comes Back Online

Run this script to ensure controller_2 stays disabled:

```bash
./ensure-controller-2-disabled.sh
```

This will:
1. Stop controller_2 if it's running
2. Disable auto-start for controller_2
3. Verify controller_1 status

## Manual Commands

If you need to manually disable controller_2:

```bash
ssh sub67-watcher
sudo systemctl stop frontline-watcher-controller_2
sudo systemctl disable frontline-watcher-controller_2
```

## Verify Status

```bash
./control-controllers.sh status
```

Should show:
- ✅ Controller 1: RUNNING (or enabled)
- ❌ Controller 2: STOPPED (and disabled)

## Re-enable Controller 2 (When Ready)

When you're ready to test controller_2 again:

```bash
./control-controllers.sh start 2
ssh sub67-watcher 'sudo systemctl enable frontline-watcher-controller_2'
```

## Why Controller 2 Was Disabled

- Rate limiting issues when both controllers were running
- Need to test with only controller_1 first
- Will re-enable after fixes are verified
