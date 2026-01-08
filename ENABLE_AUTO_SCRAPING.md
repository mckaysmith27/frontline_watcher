# Enable Automatic Scraping - Configurable Setup

## Quick Start

### Step 1: Configure Scrapers

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

**Configuration Options:**
- `numScrapers`: Number of master accounts (1-5)
- `scrapeIntervalSeconds`: How often each scraper runs (e.g., 16 seconds)
- `activeTimeWindows`: When scrapers should be active (24-hour format)

**Automatic Calculation:**
- If `scrapeIntervalSeconds = 16` and `numScrapers = 2`
- Each scraper runs every 16 seconds
- Combined frequency: ~8 seconds between scrapes (16 / 2 = 8)

### Step 2: Set Up Credentials for Each Controller

For Controller 1 (if not already set):
```bash
./setup-controller-credentials.sh 1 username1 password1
```

For Controller 2:
```bash
./setup-controller-credentials.sh 2 username2 password2
```

(Repeat for additional controllers)

### Step 3: Create/Update Cloud Run Jobs

```bash
./setup-scrapers-configurable.sh
```

This creates/updates jobs based on your config.

### Step 4: Set Up Automatic Scheduling

```bash
./setup-scheduler-configurable.sh
```

This creates Cloud Scheduler jobs that run your scrapers automatically.

### Step 5: Start Scraping

```bash
./control-scrapers.sh start
```

## Example: 2 Scrapers, 16 Second Intervals

**Configuration:**
```json
{
  "numScrapers": 2,
  "scrapeIntervalSeconds": 16,
  "activeTimeWindows": [
    {"start": "06:00", "end": "20:00", "timezone": "America/Denver"}
  ]
}
```

**Result:**
- Controller 1 runs every 16 seconds (offset: 0s)
- Controller 2 runs every 16 seconds (offset: 8s)
- Combined: Site scraped every ~8 seconds
- Active: 6 AM - 8 PM Mountain Time

## Control Commands

```bash
# Check status
./control-scrapers.sh status

# Start automatic scraping
./control-scrapers.sh start

# Stop automatic scraping
./control-scrapers.sh stop
```

## Time Windows

Time windows control when scrapers are active. Outside these windows, scrapers won't run.

**Example - Business Hours Only:**
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

## Changing Configuration

1. Edit `scraper-config.json`
2. Run `./setup-scrapers-configurable.sh` (updates jobs)
3. Run `./setup-scheduler-configurable.sh` (updates schedulers)
4. Restart: `./control-scrapers.sh stop && ./control-scrapers.sh start`

## Troubleshooting

**"No credentials found"**
- Run `./setup-controller-credentials.sh <num> <user> <pass>` for each controller

**"Scheduler not running"**
- Check status: `./control-scrapers.sh status`
- Start: `./control-scrapers.sh start`

**"Jobs not executing"**
- Check Cloud Run logs in console
- Verify secrets are set correctly
- Check time windows (scrapers won't run outside active windows)

