# Start EC2 Instance - Instructions

## Option 1: AWS Console (Recommended)

1. Go to [AWS EC2 Console](https://console.aws.amazon.com/ec2/)
2. Find instance: `frontline-watcher_V6plus` (or instance ID: `i-038353e74ba7344a0`)
3. Select the instance
4. Click **"Start instance"** (or **"Actions" → "Instance State" → "Start"**)
5. Wait 1-2 minutes for instance to be "running"

## Option 2: AWS CLI (If installed)

```bash
aws ec2 start-instances --instance-ids i-038353e74ba7344a0
```

## After Instance is Running

Once the instance shows "running" status, run:

```bash
./startup-ec2-complete.sh
```

This script will:
1. ✅ Wait for EC2 to be reachable (1-2 minutes)
2. ✅ Install auto-disable service for controller_2
3. ✅ Disable controller_2
4. ✅ Enable controller_1
5. ✅ Verify everything is set up correctly

## What Happens

- **Controller 2**: Will be disabled and won't start on boot
- **Controller 1**: Will be enabled and ready to start
- **Auto-disable service**: Installed to ensure controller_2 stays disabled

## Manual Steps (If Script Fails)

If the script doesn't work, you can run these manually:

```bash
ssh sub67-watcher

# Install auto-disable service
cd /opt/frontline-watcher
sudo ./ec2/disable-controller-2-on-boot.sh

# Disable controller_2
sudo systemctl stop frontline-watcher-controller_2
sudo systemctl disable frontline-watcher-controller_2

# Enable controller_1
sudo systemctl enable frontline-watcher-controller_1

# Start controller_1
sudo systemctl start frontline-watcher-controller_1
```

## Verification

After running the script, verify:

```bash
./control-controllers.sh status
```

Should show:
- ✅ Controller 1: RUNNING (or enabled)
- ❌ Controller 2: STOPPED (and disabled)
