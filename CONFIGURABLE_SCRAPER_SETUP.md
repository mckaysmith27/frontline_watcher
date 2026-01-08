# Configurable Scraper Setup - Complete Guide

## ✅ What's Been Done

1. ✅ Made scraper count configurable (not hardcoded to 5)
2. ✅ Made scrape interval configurable (e.g., every 16 seconds)
3. ✅ Added time window support (when scrapers should run)
4. ✅ Automatic offset calculation (16s / 2 scrapers = 8s between scrapes)
5. ✅ Created credential setup script for each controller

## 📋 Quick Start (2 Scrapers, 16-Second Intervals)

### Option 1: All-in-One Script

```bash
./QUICK_SETUP_2_SCRAPERS.sh
```

This will:
1. Prompt for Controller 2 credentials
2. Set up all jobs
3. Configure schedulers
4. Enable automatic scraping

### Option 2: Step-by-Step

**Step 1: Set up Controller 2 credentials**
```bash
./setup-controller-credentials.sh 2 username2 password2
```

**Step 2: Create/Update jobs**
```bash
./setup-scrapers-configurable.sh
```

**Step 3: Set up schedulers**
```bash
./setup-scheduler-configurable.sh
```

**Step 4: Start scraping**
```bash
./control-scrapers.sh start
```

## ⚙️ Configuration

Edit `scraper-config.json`:

```json
{
  "numScrapers": 2,
  "scrapeIntervalSeconds": 16,
  "activeTimeWindows": [
    {
      "start": "06:00",
      "end": "20:00",
      "timezone": "America/Denver"
    }
  ]
}
```

### Configuration Options

**`numScrapers`**: Number of master accounts (1-5)
- Each scraper needs its own credentials
- More scrapers = faster combined scraping frequency

**`scrapeIntervalSeconds`**: How often each scraper runs
- Example: `16` = each scraper runs every 16 seconds
- Minimum: 1 second (but Cloud Scheduler minimum is 1 minute)

**`activeTimeWindows`**: When scrapers should be active
- Format: `"HH:MM"` (24-hour format)
- Multiple windows supported
- Outside windows, scrapers won't run

### Automatic Calculations

**Offset Calculation:**
- If `scrapeIntervalSeconds = 16` and `numScrapers = 2`
- Offset interval = 16 / 2 = 8 seconds
- Controller 1: offset 0s (runs at :00, :16, :32, etc.)
- Controller 2: offset 8s (runs at :08, :24, :40, etc.)
- **Combined frequency: ~8 seconds between scrapes**

**Example with 3 scrapers, 15-second intervals:**
- Offset interval = 15 / 3 = 5 seconds
- Controller 1: offset 0s
- Controller 2: offset 5s
- Controller 3: offset 10s
- **Combined frequency: ~5 seconds between scrapes**

## 🔐 Setting Up Credentials

For each controller, run:
```bash
./setup-controller-credentials.sh <controller_number> <username> <password>
```

**Examples:**
```bash
# Controller 1
./setup-controller-credentials.sh 1 user1 pass1

# Controller 2
./setup-controller-credentials.sh 2 user2 pass2

# Controller 3 (if using 3+ scrapers)
./setup-controller-credentials.sh 3 user3 pass3
```

## ⏰ Time Windows

Time windows control when scrapers are active. Outside these windows, scrapers won't run (saves costs).

**Example - Business Hours:**
```json
"activeTimeWindows": [
  {"start": "06:00", "end": "20:00", "timezone": "America/Denver"}
]
```

**Example - Multiple Windows:**
```json
"activeTimeWindows": [
  {"start": "06:00", "end": "09:00", "timezone": "America/Denver"},
  {"start": "14:00", "end": "17:00", "timezone": "America/Denver"}
]
```

**Example - 24/7:**
```json
"activeTimeWindows": [
  {"start": "00:00", "end": "23:59", "timezone": "America/Denver"}
]
```

## 🎮 Control Commands

```bash
# Check status
./control-scrapers.sh status

# Start automatic scraping
./control-scrapers.sh start

# Stop automatic scraping
./control-scrapers.sh stop
```

## 📊 Current Configuration

Based on `scraper-config.json`:
- **Number of scrapers**: 2
- **Scrape interval**: 16 seconds per scraper
- **Combined frequency**: ~8 seconds between scrapes
- **Active time**: 6 AM - 8 PM Mountain Time

## 🔄 Changing Configuration

1. **Edit `scraper-config.json`**
2. **Update jobs**: `./setup-scrapers-configurable.sh`
3. **Update schedulers**: `./setup-scheduler-configurable.sh`
4. **Restart**: `./control-scrapers.sh stop && ./control-scrapers.sh start`

## 📝 Files Created

- `scraper-config.json` - Configuration file
- `setup-scrapers-configurable.sh` - Creates/updates Cloud Run Jobs
- `setup-scheduler-configurable.sh` - Sets up Cloud Scheduler
- `setup-controller-credentials.sh` - Sets up credentials for each controller
- `control-scrapers.sh` - Control script (start/stop/status)
- `QUICK_SETUP_2_SCRAPERS.sh` - All-in-one setup script

## 🆘 Troubleshooting

**"No credentials found for controller X"**
- Run: `./setup-controller-credentials.sh X username password`

**"Scheduler not running"**
- Check: `./control-scrapers.sh status`
- Start: `./control-scrapers.sh start`

**"Jobs not executing"**
- Check Cloud Run logs in console
- Verify time windows (scrapers won't run outside active windows)
- Check that secrets are set correctly

**"Want to change number of scrapers"**
1. Edit `scraper-config.json` → change `numScrapers`
2. Run `./setup-scrapers-configurable.sh`
3. Run `./setup-scheduler-configurable.sh`
4. Set up credentials for new controllers if needed

## 💡 Tips

- **Start small**: Begin with 2 scrapers, then add more if needed
- **Monitor costs**: More scrapers = more Cloud Run executions = higher cost
- **Time windows**: Use time windows to save costs during off-hours
- **Interval**: 16 seconds is a good balance (not too aggressive, not too slow)

