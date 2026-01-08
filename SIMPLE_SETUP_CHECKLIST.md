# Simple Setup Checklist - New EC2 Instance

## What You Need (Quick List)

### ✅ Already Have:
- ✅ Firebase credentials file: `firebase-service-account.json` (found in project)
- ✅ Credentials in Google Secret Manager (script will retrieve automatically)
- ✅ SSH key: `~/.ssh/frontline-watcher_V6plus-key` (or similar)

### 📋 What You Need to Do:

1. **Create EC2 Instance** (AWS Console)
   - Instance type: `t3.micro` or `t3.small`
   - OS: Ubuntu 22.04 LTS
   - Storage: 30 GB
   - Security Group: Allow SSH (port 22) from your IP
   - Key Pair: Use existing `frontline-watcher_V6plus-key`
   - **Note the Public IP** after it starts

2. **Update SSH Config** (if using new instance)
   - Add to `~/.ssh/config`:
   ```
   Host sub67-watcher-new
       HostName <PUBLIC_IP>
       User ubuntu
       IdentityFile ~/.ssh/frontline-watcher_V6plus-key
   ```

3. **Run Setup Script**
   ```bash
   cd ~/Sub67/frontline_watcher
   ./ec2/interactive-setup.sh
   ```

## What the Script Will Ask

1. **EC2 Host**: 
   - Enter: `sub67-watcher-new` (or `ubuntu@<PUBLIC_IP>`)

2. **Retrieve credentials from Secret Manager?**
   - Answer: `y` (yes)

3. **How many controllers?**
   - Answer: `1` (only controller_1)

4. **Ready to deploy?**
   - Answer: `y` (yes)

## That's It!

The script will:
- ✅ Retrieve all credentials automatically
- ✅ Upload code to EC2
- ✅ Install everything (Python, Playwright, etc.)
- ✅ Set up **ONLY controller_1** (controller_2 is blocked)
- ✅ Start controller_1

## After Setup

```bash
# Check status
./control-controllers.sh status

# View logs
./view-ec2-logs.sh 1 follow
```

## Summary

**You need:**
1. EC2 instance (create in AWS Console)
2. Public IP address
3. Run: `./ec2/interactive-setup.sh`

**Everything else is automatic!**
