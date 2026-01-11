# EC2 Migration - Quick Start Guide

## What You Need

Before running the setup, gather this information:

### Required:
1. **EC2 Instance** (or we can create one for you)
   - Type: t3.medium
   - OS: Ubuntu 22.04 LTS
   - SSH access configured

2. **Frontline Credentials**
   - Username
   - Password
   - District ID

3. **Firebase Credentials**
   - Service account JSON file (already have: `firebase-service-account.json`)

### Optional:
- NTFY topic (for notifications)
- AWS CLI (if you want us to create the instance)

## Option 1: Automated Setup (Recommended)

Run the interactive setup script - it will guide you through everything:

```bash
./ec2/interactive-setup.sh
```

This script will:
- ✅ Check prerequisites
- ✅ Create EC2 instance (if needed and AWS CLI available)
- ✅ Retrieve credentials from Google Secret Manager (if available)
- ✅ Upload all files to EC2
- ✅ Run setup scripts
- ✅ Configure all controllers
- ✅ Start services

## Option 2: Manual Setup

If you prefer to do it step by step:

### 1. Create EC2 Instance

Via AWS Console:
- Launch t3.medium instance
- Ubuntu 22.04 LTS
- Configure security group (SSH from your IP)
- Note the public IP

Via AWS CLI:
```bash
./ec2/create-ec2-instance.sh t3.medium your-key-pair sg-xxxxx
```

### 2. Run Setup on EC2

```bash
# SSH into instance
ssh ubuntu@your-ec2-ip

# Clone repository
git clone https://github.com/mckaysmith27/frontline_watcher.git
cd frontline_watcher

# Run setup
./ec2/setup-ec2.sh
```

### 3. Configure Credentials

```bash
# Upload Firebase credentials
# From your local machine:
scp firebase-service-account.json ubuntu@your-ec2-ip:/opt/frontline-watcher/firebase-credentials.json

# On EC2, create .env files
cd /opt/frontline-watcher
cp .env.template .env.controller_1
nano .env.controller_1  # Edit with your credentials
```

### 4. Install and Start Services

```bash
# Install service for controller 1
sudo ./ec2/install-service.sh controller_1

# Start service
sudo systemctl start frontline-watcher-controller_1
sudo systemctl enable frontline-watcher-controller_1

# For all 5 controllers:
sudo ./ec2/setup-all-controllers.sh 5
```

## Verify It's Working

1. **Check service status:**
   ```bash
   ssh ubuntu@your-ec2-ip 'sudo systemctl status frontline-watcher-controller_1'
   ```

2. **View logs:**
   ```bash
   ssh ubuntu@your-ec2-ip 'sudo journalctl -u frontline-watcher-controller_1 -f'
   ```

3. **Check Firestore:**
   - Go to Firebase Console
   - Check `job_events` collection
   - Look for new events with `controllerId: "controller_1"`

## Troubleshooting

### Can't SSH to EC2
- Check security group allows SSH from your IP
- Verify key pair is correct
- Check instance is running

### Service won't start
- Check `.env` file exists and has correct values
- View error logs: `sudo journalctl -u frontline-watcher-controller_1 -n 50`
- Test manually: `cd /opt/frontline-watcher && source venv/bin/activate && python frontline_watcher_refactored.py`

### No job events in Firestore
- Check Firebase credentials file path
- Verify DISTRICT_ID is correct
- Check service logs for errors

## Next Steps

Once everything is working:
1. Monitor for 24-48 hours
2. Verify job events are being created
3. Stop Cloud Run jobs to save costs
4. Set up monitoring/alerts

## Need Help?

See the full guide: `EC2_MIGRATION_GUIDE.md`
