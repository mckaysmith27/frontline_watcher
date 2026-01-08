# Ready to Set Up Controller 2

## Current Status

✅ **Controller 1**: Updated and ready  
⏳ **Controller 2**: Needs credentials  

## Next Steps

### Option 1: Interactive Setup (Recommended)

Run this script - it will prompt you for credentials:
```bash
./setup-controller-2-interactive.sh
```

### Option 2: Direct Command

If you have the credentials ready:
```bash
./setup-controller-credentials.sh 2 <username> <password>
```

Replace `<username>` and `<password>` with Controller 2's actual credentials.

### After Setting Credentials

Once credentials are set, run:
```bash
# 1. Update jobs (will now work for controller 2)
./setup-scrapers-configurable.sh

# 2. Set up schedulers
./setup-scheduler-configurable.sh

# 3. Enable automatic scraping
./control-scrapers.sh start
```

## What Will Happen

1. **Credentials Setup**: Creates secrets `frontline-username-controller-2` and `frontline-password-controller-2`
2. **Job Update**: Updates Controller 2 job to use the new credentials
3. **Scheduler Setup**: Creates scheduler to run Controller 2 every 16 seconds (offset by 8 seconds)
4. **Start Scraping**: Enables automatic execution

## Configuration

- **2 scrapers** (Controller 1 and Controller 2)
- **16-second intervals** per scraper
- **~8 seconds** combined frequency
- **Active time**: 6 AM - 8 PM Mountain Time

## Ready?

Run: `./setup-controller-2-interactive.sh`

