# New EC2 Instance Setup - Complete Guide

## What You Need

### 1. EC2 Instance Details
- **Instance ID** or **Public IP** (after you create it)
- **SSH Key** (should already be in `~/.ssh/`)
- **SSH Config** (should already be set up as `sub67-watcher`)

### 2. Credentials (Already in Google Secret Manager)
The setup script will automatically retrieve these from Google Secret Manager:
- ✅ Frontline username
- ✅ Frontline password  
- ✅ District ID
- ✅ Firebase project ID

### 3. Firebase Credentials File
- **File**: `firebase-service-account.json` (should be in project root)
- If missing, you'll need to download it from Firebase Console

## Step-by-Step Setup

### Step 1: Create EC2 Instance

1. Go to [AWS EC2 Console](https://console.aws.amazon.com/ec2/)
2. Click **"Launch Instance"**
3. Configure:
   - **Name**: `frontline-watcher-new` (or any name)
   - **AMI**: Ubuntu 22.04 LTS
   - **Instance Type**: `t3.micro` (or `t3.small` if you prefer)
   - **Key Pair**: Use existing `frontline-watcher_V6plus-key` (or create new)
   - **Storage**: 30 GB gp3
   - **Security Group**: Allow SSH (port 22) from your IP
4. Click **"Launch Instance"**
5. Wait for status to show **"Running"**
6. Note the **Public IP** address

### Step 2: Update SSH Config (If New Instance)

If you're using a different instance, add to `~/.ssh/config`:

```
Host sub67-watcher-new
    HostName <PUBLIC_IP>
    User ubuntu
    IdentityFile ~/.ssh/frontline-watcher_V6plus-key
```

Or use the existing `sub67-watcher` if you're replacing the old instance.

### Step 3: Run Setup Script

From your project directory:

```bash
cd ~/Sub67/frontline_watcher
./ec2/interactive-setup.sh
```

The script will:
1. ✅ Ask for EC2 host (or use default)
2. ✅ Ask how many controllers (use **1** - only controller_1)
3. ✅ Retrieve credentials from Google Secret Manager
4. ✅ Check for Firebase credentials file
5. ✅ Upload code to EC2
6. ✅ Install Python, Playwright, dependencies
7. ✅ Create .env file for controller_1 only
8. ✅ Install systemd service for controller_1 only
9. ✅ Start controller_1
10. ✅ **SKIP controller_2** (permanently disabled in code)

### Step 4: Verify Setup

```bash
# Check status
./control-controllers.sh status

# View logs
./view-ec2-logs.sh 1 follow
```

## What Gets Set Up

✅ **Controller 1**: Installed and started
🛑 **Controller 2**: SKIPPED (permanently disabled)
🛑 **Controllers 3-5**: SKIPPED (not needed)

## Quick Setup (If You Have Everything)

```bash
# 1. Create EC2 instance in AWS Console
# 2. Note the Public IP

# 3. Run setup (replace with your instance IP if different)
./ec2/interactive-setup.sh

# When prompted:
# - EC2 host: sub67-watcher (or ubuntu@<IP>)
# - Number of controllers: 1
# - Confirm credentials from Secret Manager: y

# 4. Wait for setup to complete (5-10 minutes)

# 5. Verify
./control-controllers.sh status
```

## Troubleshooting

### Missing Firebase Credentials
If `firebase-service-account.json` is missing:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Project Settings → Service Accounts
3. Click "Generate New Private Key"
4. Save as `firebase-service-account.json` in project root

### SSH Connection Issues
```bash
# Test SSH manually first
ssh sub67-watcher 'echo "Connected"'

# If that works, the setup script will work
```

### Credentials Not in Secret Manager
If setup can't retrieve credentials:
- You'll need to provide them manually
- Or add them to Secret Manager first

## Summary

**You need:**
1. ✅ EC2 instance (create in AWS Console)
2. ✅ SSH access (should already work)
3. ✅ Firebase credentials file (`firebase-service-account.json`)
4. ✅ Credentials in Google Secret Manager (should already be there)

**Then run:**
```bash
./ec2/interactive-setup.sh
```

**Result:**
- ✅ Only controller_1 installed and running
- 🛑 Controller_2 will NEVER be installed (blocked in code)
