# EC2 Deployment Files

This directory contains all files needed to deploy Frontline Watcher scrapers to Amazon EC2.

## Files

- **setup-ec2.sh** - Initial EC2 instance setup (run once)
- **install-service.sh** - Install systemd service for a controller
- **deploy-to-ec2.sh** - Deploy code updates to EC2
- **EC2_MIGRATION_GUIDE.md** - Complete migration guide

## Quick Start

### 1. On EC2 Instance:
```bash
# Run initial setup
./ec2/setup-ec2.sh

# Configure credentials
cp /opt/frontline-watcher/.env.template /opt/frontline-watcher/.env
nano /opt/frontline-watcher/.env  # Edit with your values

# Install service for controller 1
sudo ./ec2/install-service.sh controller_1

# Start service
sudo systemctl start frontline-watcher-controller_1
sudo systemctl enable frontline-watcher-controller_1  # Auto-start on boot
```

### 2. From Local Machine (for updates):
```bash
./ec2/deploy-to-ec2.sh ubuntu@your-ec2-ip controller_1
```

## Directory Structure on EC2

```
/opt/frontline-watcher/
├── frontline_watcher.py      # Main script
├── requirements_raw.txt      # Python dependencies
├── .env                      # Environment variables (create from template)
├── firebase-credentials.json # Firebase service account (upload separately)
├── venv/                     # Python virtual environment
└── .env.template            # Template for .env file

/var/log/frontline-watcher/
├── controller_1.log
├── controller_1.error.log
├── controller_2.log
└── ...
```

## Service Management

```bash
# Start service
sudo systemctl start frontline-watcher-controller_1

# Stop service
sudo systemctl stop frontline-watcher-controller_1

# Restart service
sudo systemctl restart frontline-watcher-controller_1

# Check status
sudo systemctl status frontline-watcher-controller_1

# View logs
sudo journalctl -u frontline-watcher-controller_1 -f

# Enable auto-start on boot
sudo systemctl enable frontline-watcher-controller_1

# Disable auto-start
sudo systemctl disable frontline-watcher-controller_1
```

## Multiple Controllers

To run multiple controllers on the same EC2 instance:

1. Create separate .env files for each:
   ```bash
   cp /opt/frontline-watcher/.env /opt/frontline-watcher/.env.controller_1
   cp /opt/frontline-watcher/.env /opt/frontline-watcher/.env.controller_2
   # Edit each with different CONTROLLER_ID
   ```

2. Install services:
   ```bash
   sudo ./ec2/install-service.sh controller_1
   sudo ./ec2/install-service.sh controller_2
   # ... repeat for all controllers
   ```

3. Start all services:
   ```bash
   for i in {1..5}; do
     sudo systemctl start frontline-watcher-controller_${i}
     sudo systemctl enable frontline-watcher-controller_${i}
   done
   ```

## Notes

- **t3.medium** has 4GB RAM - can run 2-3 controllers comfortably
- For 5 controllers, consider **t3.large** (8GB RAM) or multiple instances
- Each controller uses ~500MB-1GB RAM
- Services auto-restart on failure (RestartSec=10)
- Logs rotate automatically via systemd
