# Quick Start Steps - EC2 Setup

## Step-by-Step Instructions

### Step 1: Start EC2 Instance
1. Go to [AWS EC2 Console](https://console.aws.amazon.com/ec2/)
2. Find instance: `frontline-watcher_V6plus`
3. Click **"Start instance"**
4. Wait until status shows **"running"** (usually 1-2 minutes)

### Step 2: Open Terminal on Your Mac
- Open Terminal app
- You'll run the script from your **local Mac**, not on EC2

### Step 3: Navigate to Project Directory
```bash
cd ~/Sub67/frontline_watcher
```

Or if you're already in the project:
```bash
pwd
# Should show: /Users/mckay/Sub67/frontline_watcher
```

### Step 4: Run the Setup Script
```bash
./startup-ec2-complete.sh
```

**That's it!** The script will:
- Connect to EC2 automatically (no manual SSH needed)
- Wait for EC2 to be ready
- Install everything
- Set up controller_2 to be disabled
- Enable controller_1

### Step 5: Start Controller 1 (After Script Completes)
```bash
./control-controllers.sh start 1
```

### Step 6: Verify Everything
```bash
./control-controllers.sh status
```

## Important Notes

✅ **You don't need to SSH manually** - the script does it for you
✅ **Run from your Mac** - not on EC2
✅ **Make sure you're in the project directory** - `cd ~/Sub67/frontline_watcher`

## If You Get "Permission Denied"

If you see "Permission denied", make the script executable:
```bash
chmod +x startup-ec2-complete.sh
./startup-ec2-complete.sh
```

## If SSH Connection Fails

The script will wait up to 5 minutes for EC2 to be reachable. If it times out:
1. Check EC2 status in AWS Console (should be "running")
2. Wait another minute (SSH can take 1-2 minutes after instance starts)
3. Try running the script again

## Summary

```bash
# 1. Start EC2 in AWS Console (wait for "running")

# 2. On your Mac, in terminal:
cd ~/Sub67/frontline_watcher

# 3. Run the script:
./startup-ec2-complete.sh

# 4. After it completes, start controller_1:
./control-controllers.sh start 1
```
