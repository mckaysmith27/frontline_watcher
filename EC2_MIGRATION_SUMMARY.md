# EC2 Migration - Complete Package Summary

## ✅ What's Been Created

### 1. **Setup Scripts** (`ec2/`)
- **setup-ec2.sh** - Initial EC2 instance setup (Python, Playwright, dependencies)
- **setup-all-controllers.sh** - Set up all 5 controllers at once
- **install-service.sh** - Install systemd service for a controller

### 2. **Deployment Scripts** (`ec2/`)
- **deploy-to-ec2.sh** - Full deployment with service restart
- **quick-deploy.sh** - Fast code updates without full setup

### 3. **Management Scripts** (`ec2/`)
- **monitor-services.sh** - Monitor, start, stop, restart services
- **create-ec2-instance.sh** - AWS CLI script to launch EC2 instance

### 4. **Documentation**
- **EC2_MIGRATION_GUIDE.md** - Complete step-by-step migration guide
- **EC2_COST_SAVINGS.md** - Detailed cost analysis and ROI
- **ec2/README.md** - Quick reference for EC2 deployment

## 🚀 Quick Start

### On Your Local Machine:

1. **Create EC2 Instance** (optional - can also use AWS Console):
   ```bash
   ./ec2/create-ec2-instance.sh t3.medium your-key-pair sg-xxxxx
   ```

2. **Deploy to EC2**:
   ```bash
   # First time setup
   ssh ubuntu@your-ec2-ip
   git clone https://github.com/mckaysmith27/frontline_watcher.git
   cd frontline_watcher
   ./ec2/setup-ec2.sh
   
   # Configure credentials
   cp /opt/frontline-watcher/.env.template /opt/frontline-watcher/.env.controller_1
   nano /opt/frontline-watcher/.env.controller_1  # Edit with your values
   
   # Install and start services
   sudo ./ec2/setup-all-controllers.sh 5
   ```

3. **Deploy Updates** (from local machine):
   ```bash
   ./ec2/quick-deploy.sh ubuntu@your-ec2-ip
   ```

### On EC2 Instance:

```bash
# Monitor all services
./ec2/monitor-services.sh status

# View logs for controller 1
./ec2/monitor-services.sh logs 1

# Restart all services
./ec2/monitor-services.sh restart
```

## 💰 Cost Savings

- **Current (Cloud Run)**: ~$150-300/month
- **EC2 t3.medium (2 instances)**: ~$60/month
- **Savings**: **70-85% reduction**
- **With Reserved Instances**: ~$36/month = **85-90% savings**

## 📋 Migration Checklist

- [ ] Launch EC2 instance (t3.medium, Ubuntu 22.04)
- [ ] Run `setup-ec2.sh` on EC2
- [ ] Upload `firebase-credentials.json` to `/opt/frontline-watcher/`
- [ ] Create `.env.controller_*` files for each controller
- [ ] Run `setup-all-controllers.sh 5`
- [ ] Start services: `sudo systemctl start frontline-watcher-controller_*`
- [ ] Verify job events in Firestore
- [ ] Monitor for 24-48 hours
- [ ] Stop Cloud Run jobs
- [ ] Monitor EC2 costs

## 🔧 Key Features

1. **Auto-Restart**: Services automatically restart on failure
2. **Separate Logs**: Each controller has its own log file
3. **Easy Updates**: `quick-deploy.sh` updates code and restarts services
4. **Multi-Controller**: Run all 5 controllers on 2 instances
5. **Cost Optimized**: 70-90% cheaper than Cloud Run

## 📁 File Structure on EC2

```
/opt/frontline-watcher/
├── frontline_watcher.py
├── requirements_raw.txt
├── .env.controller_1
├── .env.controller_2
├── .env.controller_3
├── .env.controller_4
├── .env.controller_5
├── firebase-credentials.json
└── venv/

/var/log/frontline-watcher/
├── controller_1.log
├── controller_1.error.log
├── controller_2.log
└── ...
```

## 🎯 Next Steps

1. **Test Migration**: Set up 1 controller on EC2 and verify
2. **Full Migration**: Deploy all 5 controllers
3. **Monitor**: Watch costs and performance for 1 week
4. **Optimize**: Consider Reserved Instances for long-term savings
5. **Cutover**: Stop Cloud Run jobs once EC2 is stable

## 📚 Documentation

- **Full Guide**: See `EC2_MIGRATION_GUIDE.md`
- **Cost Analysis**: See `EC2_COST_SAVINGS.md`
- **Quick Reference**: See `ec2/README.md`

## ⚠️ Important Notes

1. **Memory**: t3.medium has 4GB RAM - can run 2-3 controllers comfortably
2. **For 5 Controllers**: Use 2× t3.medium instances or 1× t3.large
3. **Security**: Restrict SSH to your IP, use IAM roles
4. **Backup**: Keep Cloud Run jobs running during initial migration
5. **Monitoring**: Set up CloudWatch or similar for alerts

## 🆘 Troubleshooting

See `EC2_MIGRATION_GUIDE.md` for detailed troubleshooting steps.

Quick fixes:
- **Service won't start**: Check `.env` file and logs
- **Playwright issues**: Run `playwright install chromium` in venv
- **Firebase errors**: Verify credentials file path

---

**Ready to migrate?** Start with the migration guide and work through the checklist step by step!
