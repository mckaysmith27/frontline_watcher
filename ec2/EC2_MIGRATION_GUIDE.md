# EC2 Migration Guide - Frontline Watcher Scrapers

## Overview

This guide helps you migrate the Frontline Watcher scraping process from Cloud Run to Amazon EC2 (t3.medium) to reduce costs.

## Cost Comparison

### Cloud Run (Current)
- **Cost**: ~$0.00001 per job execution
- **With 5 controllers running every minute**: ~$5-10/day
- **Monthly**: ~$150-300

### EC2 t3.medium
- **Cost**: ~$0.0416/hour = $1/day = **$30/month**
- **Savings**: ~80-90% reduction in costs

## Prerequisites

1. AWS Account with EC2 access
2. EC2 t3.medium instance (Ubuntu 22.04 LTS recommended)
3. Security group allowing outbound HTTPS (for Frontline, Firebase, NTFY)
4. SSH access to EC2 instance

## Step 1: Launch EC2 Instance

### Via AWS Console:
1. Go to EC2 Dashboard
2. Launch Instance
3. Choose: **Ubuntu Server 22.04 LTS**
4. Instance Type: **t3.medium** (2 vCPU, 4 GB RAM)
5. Configure security group:
   - Allow SSH (port 22) from your IP
   - Allow all outbound traffic (default)
6. Create/select key pair for SSH access
7. Launch instance

### Via AWS CLI:
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-group-ids sg-xxxxx \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=frontline-watcher}]'
```

## Step 2: Initial Setup on EC2

### Connect to EC2:
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### Run Setup Script:
```bash
# Clone repository or upload files
git clone https://github.com/mckaysmith27/frontline_watcher.git
cd frontline_watcher

# Run setup
chmod +x ec2/setup-ec2.sh
./ec2/setup-ec2.sh
```

This will:
- Install Python 3 and dependencies
- Install Playwright and Chromium
- Create application directory at `/opt/frontline-watcher`
- Set up virtual environment
- Create logs directory

## Step 3: Configure Credentials

### Copy Firebase Credentials:
```bash
# From your local machine
scp -i your-key.pem firebase-service-account.json ubuntu@your-ec2-ip:/opt/frontline-watcher/firebase-credentials.json
```

### Create .env File:
```bash
cd /opt/frontline-watcher
cp .env.template .env
nano .env  # Edit with your credentials
```

Required variables:
```env
CONTROLLER_ID=controller_1
DISTRICT_ID=your_district_id
FIREBASE_PROJECT_ID=sub67-d4648
FIREBASE_CREDENTIALS_PATH=/opt/frontline-watcher/firebase-credentials.json
FRONTLINE_USERNAME=your_username
FRONTLINE_PASSWORD=your_password
```

## Step 4: Install Systemd Service

For each controller (1-5):

```bash
cd /opt/frontline-watcher
sudo chmod +x ec2/install-service.sh
sudo ./ec2/install-service.sh controller_1
sudo ./ec2/install-service.sh controller_2
# ... repeat for controllers 3-5
```

### Enable Auto-Start:
```bash
sudo systemctl enable frontline-watcher-controller_1
sudo systemctl enable frontline-watcher-controller_2
# ... repeat for all controllers
```

### Start Services:
```bash
sudo systemctl start frontline-watcher-controller_1
sudo systemctl start frontline-watcher-controller_2
# ... repeat for all controllers
```

## Step 5: Verify Services

### Check Status:
```bash
sudo systemctl status frontline-watcher-controller_1
```

### View Logs:
```bash
# Real-time logs
sudo journalctl -u frontline-watcher-controller_1 -f

# Last 100 lines
sudo journalctl -u frontline-watcher-controller_1 -n 100

# Log files
tail -f /var/log/frontline-watcher/controller_1.log
```

### Check Firestore:
- Go to Firebase Console
- Check `job_events` collection for new events
- Verify `controllerId` is `controller_1`, `controller_2`, etc.

## Step 6: Deploy Updates

### From Local Machine:
```bash
# Make script executable
chmod +x ec2/deploy-to-ec2.sh

# Deploy to EC2
./ec2/deploy-to-ec2.sh ubuntu@your-ec2-ip controller_1
```

This will:
- Upload updated code
- Update virtual environment
- Restart service automatically

## Step 7: Stop Cloud Run Jobs (After Verification)

Once EC2 is working and verified:

```bash
# Stop Cloud Scheduler (if enabled)
./control-scrapers.sh stop

# Or delete Cloud Run Jobs (optional)
for i in {1..5}; do
  gcloud run jobs delete frontline-scraper-controller-${i} \
    --region us-central1 \
    --project sub67-d4648 \
    --quiet
done
```

## Monitoring

### Service Health:
```bash
# Check all services
for i in {1..5}; do
  echo "Controller $i:"
  sudo systemctl is-active frontline-watcher-controller_${i}
done
```

### Resource Usage:
```bash
# CPU and Memory
htop

# Disk usage
df -h

# Network
iftop
```

### Set Up CloudWatch (Optional):
```bash
# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Configure and start
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s
```

## Troubleshooting

### Service Won't Start:
```bash
# Check service status
sudo systemctl status frontline-watcher-controller_1

# Check logs
sudo journalctl -u frontline-watcher-controller_1 -n 50

# Check .env file
cat /opt/frontline-watcher/.env

# Test manually
cd /opt/frontline-watcher
source venv/bin/activate
python frontline_watcher.py
```

### Playwright Issues:
```bash
# Reinstall Playwright browsers
cd /opt/frontline-watcher
source venv/bin/activate
playwright install chromium
playwright install-deps chromium
```

### Firebase Connection Issues:
```bash
# Verify credentials file
ls -la /opt/frontline-watcher/firebase-credentials.json

# Test Firebase connection
cd /opt/frontline-watcher
source venv/bin/activate
python -c "import firebase_admin; from firebase_admin import firestore; print('Firebase OK')"
```

### High Memory Usage:
- t3.medium has 4GB RAM
- Each controller uses ~500MB-1GB
- Running 5 controllers: ~2.5-5GB (may need t3.large for 5 controllers)
- Consider running 2-3 controllers per instance

## Cost Optimization Tips

1. **Use Reserved Instances**: Save up to 72% with 1-year or 3-year commitment
2. **Spot Instances**: Save up to 90% (but can be interrupted)
3. **Auto Scaling**: Scale down during off-hours
4. **Multiple Instances**: Run 2-3 controllers per instance to balance cost/performance

## Security Best Practices

1. **SSH Key Only**: Disable password authentication
2. **Security Groups**: Restrict SSH to your IP only
3. **IAM Roles**: Use IAM roles instead of access keys
4. **Secrets Management**: Consider AWS Secrets Manager for credentials
5. **Regular Updates**: Keep system packages updated

## Next Steps

1. ✅ Set up EC2 instance
2. ✅ Run initial setup
3. ✅ Configure credentials
4. ✅ Install and start services
5. ✅ Verify job events in Firestore
6. ✅ Monitor for 24-48 hours
7. ✅ Stop Cloud Run jobs
8. ✅ Monitor EC2 costs

## Support

- **Logs**: `/var/log/frontline-watcher/`
- **Service Status**: `systemctl status frontline-watcher-controller_*`
- **Firestore**: Check `job_events` collection
- **EC2 Console**: Monitor instance metrics
