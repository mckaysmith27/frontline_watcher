# Safe Startup Guide - Controller 2 Won't Start

## ✅ Solution: Auto-Disable Service

I've created a systemd service that **automatically disables controller_2 on every boot**. This means:

- ✅ **No risk** - Controller_2 will be disabled before it can start
- ✅ **Automatic** - Runs on every EC2 boot
- ✅ **Safe** - Even if controller_2 was previously enabled, it gets disabled

## How It Works

A systemd service called `disable-controller-2` runs on boot and:
1. Stops controller_2 if it's running
2. Disables controller_2 so it won't auto-start
3. Runs **BEFORE** controller_2 service starts

## Installation (When EC2 is Online)

Run this **once** to install the auto-disable mechanism:

```bash
./ec2/install-disable-controller-2.sh
```

Or manually on EC2:

```bash
ssh sub67-watcher
cd /opt/frontline-watcher
sudo ./ec2/disable-controller-2-on-boot.sh
```

## What Happens on Boot

1. EC2 starts
2. `disable-controller-2` service runs (stops and disables controller_2)
3. Controller_1 starts normally
4. Controller_2 stays disabled ✅

## Verification

After installing, verify:

```bash
ssh sub67-watcher 'sudo systemctl is-enabled disable-controller-2'
# Should show: enabled

ssh sub67-watcher 'sudo systemctl is-enabled frontline-watcher-controller_2'
# Should show: disabled (or error if service doesn't exist)
```

## Current Status

- ✅ Auto-disable script created
- ⏳ Needs to be installed on EC2 (when it comes online)
- ✅ Once installed, controller_2 will NEVER start automatically

## Manual Override (If Needed)

If you ever need to manually ensure controller_2 is off:

```bash
ssh sub67-watcher
sudo systemctl stop frontline-watcher-controller_2
sudo systemctl disable frontline-watcher-controller_2
```

## Summary

**You don't need to risk controller_2 starting!**

The auto-disable service ensures controller_2 is disabled **before** it can start, even on boot. Just install it once when EC2 comes online, and controller_2 will stay disabled forever (until you manually re-enable it).
