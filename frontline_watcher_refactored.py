print("🚨 CODE VERSION V6 — Event Publisher Only (No Filters, No Auto-Accept) 🚨")

import asyncio
import hashlib
import json
import os
import sys
import random
from datetime import datetime, timezone, timedelta
from typing import Optional
from urllib import request

from playwright.async_api import async_playwright, TimeoutError as PWTimeout
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore

# Load environment variables from .env file
load_dotenv()

# Initialize Firebase
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "sub67-d4648")

# Support both file path (EC2/local) and JSON string (for flexibility)
FIREBASE_CREDENTIALS_JSON = os.getenv("FIREBASE_CREDENTIALS")
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH")

if FIREBASE_CREDENTIALS_JSON:
    # Credentials provided as JSON string (for containerized deployments)
    try:
        import json
        cred_info = json.loads(FIREBASE_CREDENTIALS_JSON)
        cred = credentials.Certificate(cred_info)
        print("[firebase] Using credentials from FIREBASE_CREDENTIALS environment variable")
    except json.JSONDecodeError as e:
        print(f"[firebase] ERROR: FIREBASE_CREDENTIALS is not valid JSON: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"[firebase] ERROR: Failed to parse credentials: {e}")
        sys.exit(1)
elif FIREBASE_CREDENTIALS_PATH and os.path.exists(FIREBASE_CREDENTIALS_PATH):
    # EC2/Local: credentials provided as file path
    try:
        cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
        print(f"[firebase] Using credentials from file: {FIREBASE_CREDENTIALS_PATH}")
    except Exception as e:
        print(f"[firebase] ERROR: Failed to load credentials from file: {e}")
        sys.exit(1)
else:
    print("ERROR: Either FIREBASE_CREDENTIALS (JSON string) or FIREBASE_CREDENTIALS_PATH (file path) must be set")
    sys.exit(1)

try:
    firebase_admin.initialize_app(cred, {
        'projectId': FIREBASE_PROJECT_ID,
    })
    db = firestore.client()
    print("[firebase] Initialized successfully")
except Exception as e:
    print(f"[firebase] ERROR: Failed to initialize: {e}")
    sys.exit(1)

# Controller and district configuration
CONTROLLER_ID = os.getenv("CONTROLLER_ID", "controller_1")
DISTRICT_ID = os.getenv("DISTRICT_ID")
if not DISTRICT_ID:
    print("ERROR: DISTRICT_ID environment variable is required")
    sys.exit(1)

#init
SELFTEST_ENABLED = os.getenv("SELFTEST_ON_START", "0") == "1"

def _ts() -> str:
    """Utah local time (MST, UTC-7)"""
    utah = datetime.now(timezone.utc) - timedelta(hours=7)
    return f"[UTAH MST {utah:%Y-%m-%d %H:%M:%S}]"

def log(*args, **kwargs) -> None:
    """Print with timestamps prepended (shows in docker logs)."""
    print(_ts(), *args, **kwargs)

LOGIN_URL = (
    "https://login.frontlineeducation.com/login"
    "?signin=a6740188d37bd24dc70d4748ad55028e"
    "&productId=ABSMGMT&clientId=ABSMGMT#/login"
)

JOBS_URL = "https://absencesub.frontlineeducation.com/Substitute/Home"

# Randomized poll delay bounds (seconds)
MIN_DELAY = 7
MAX_DELAY = 16

def get_random_delay() -> float:
    """Return a random delay between MIN_DELAY and MAX_DELAY seconds."""
    import random
    return random.uniform(MIN_DELAY, MAX_DELAY)

def get_ntfy_topic() -> Optional[str]:
    """
    Get NTFY topic based on controller ID.
    Maps controller_1 -> "frontline-jobs-mckay"
    Maps controller_2 -> "frontline-jobs-nathan"
    """
    controller_to_topic = {
        "controller_1": "frontline-jobs-mckay",
        "controller_2": "frontline-jobs-nathan",
    }
    return controller_to_topic.get(CONTROLLER_ID)

def notify(message: str) -> None:
    """
    Send notification to NTFY topic based on controller ID.
    Uses controller-specific topic if available.
    """
    topic = get_ntfy_topic()
    if not topic:
        # Fallback to environment variable if controller mapping not found
        topic = os.getenv("NTFY_TOPIC")
        if not topic:
            return

    try:
        req = request.Request(
            f"https://ntfy.sh/{topic}",
            data=message.encode("utf-8"),
            headers={"Content-Type": "text/plain; charset=utf-8"},
            method="POST",
        )
        request.urlopen(req, timeout=5).read()
        log(f"[notify] Sent to {topic}")
    except Exception as e:
        log(f"[notify error] {e}")

def get_scraper_offset() -> int:
    """Get offset in seconds for this controller based on configurable settings"""
    # Get number of scrapers and scrape interval from environment
    NUM_SCRAPERS = int(os.getenv("NUM_SCRAPERS", "5"))
    SCRAPE_INTERVAL = int(os.getenv("SCRAPE_INTERVAL_SECONDS", "15"))
    
    # Calculate offset interval (time between each scraper)
    OFFSET_INTERVAL = SCRAPE_INTERVAL // NUM_SCRAPERS if NUM_SCRAPERS > 0 else 0
    
    # Extract controller number from CONTROLLER_ID (e.g., "controller_1" -> 1)
    try:
        controller_num = int(CONTROLLER_ID.split('_')[-1])
        offset = OFFSET_INTERVAL * (controller_num - 1)
    except (ValueError, IndexError):
        offset = 0
    
    return offset

def should_run_aggressive() -> bool:
    """Check if current time is in hot window (configurable via environment)"""
    from datetime import time as dt_time
    import json
    
    # Default hot windows: 4:30am-9:30am and 11:30am-11:00pm
    default_windows = [
        (dt_time(4, 30), dt_time(9, 30)),  # 4:30 AM - 9:30 AM
        (dt_time(11, 30), dt_time(23, 0)),  # 11:30 AM - 11:00 PM
    ]
    
    # Try to get windows from environment variable (JSON format)
    hot_windows_env = os.getenv("HOT_WINDOWS", "")
    if hot_windows_env:
        try:
            windows_config = json.loads(hot_windows_env)
            hot_windows = []
            for window in windows_config:
                start_str = window.get('start', '06:00')
                end_str = window.get('end', '20:00')
                start_hour, start_min = map(int, start_str.split(':'))
                end_hour, end_min = map(int, end_str.split(':'))
                hot_windows.append((dt_time(start_hour, start_min), dt_time(end_hour, end_min)))
        except (json.JSONDecodeError, ValueError, KeyError):
            hot_windows = default_windows
    else:
        hot_windows = default_windows
    
    now = datetime.now().time()
    
    for start, end in hot_windows:
        # Handle windows that span midnight
        if start <= end:
            if start <= now <= end:
                return True
        else:  # Window spans midnight (e.g., 22:00 to 06:00)
            if now >= start or now <= end:
                return True
    return False

# Phrases we consider "no available jobs"
NO_JOBS_MARKERS = [
    "I'm sorry. There are no available assignments at the moment.",
    "There are no available assignments at the moment.",
    "0Available Jobs",
    "0 Available Jobs",
    "Please check back later for new postings",
]

# Header labels that identify the Available Jobs table section
AVAILABLE_JOBS_HEADERS = [
    "Available Jobs",
    "Date",
    "Time",
    "Duration",
    "Location",
]

# Words that mean "this is not the Available Jobs tab, skip it"
TAB_EXCLUDE_WORDS = [
    "Past Jobs",
    "Scheduled Jobs",
    "History",
    "Preferences",
    "Resource Library",
    "RECENT NOTIFICATIONS",
    "Substitute",
    "Alpine School District",
    "SUN MON TUE WED THU FRI SAT",
]

# Weekday signatures used to recognize real job rows/blocks
WEEKDAY_WORDS = ["Mon,", "Tue,", "Wed,", "Thu,", "Fri,", "Sat,", "Sun,"]

# ---------------------------------------------------------------------
# FIRESTORE EVENT PUBLISHING
# ---------------------------------------------------------------------

def extract_keywords(text: str, job_data: Optional[dict] = None) -> list[str]:
    """
    Extract unique lowercase words from text for matching.
    Strips common punctuation and splits on whitespace.
    Also includes normalized date and duration keywords if provided.
    """
    punctuation = ",.;:!?()[]{}<>\"'\\/\n\t"
    cleaned = text.lower()
    for ch in punctuation:
        cleaned = cleaned.replace(ch, " ")
    words = [w for w in cleaned.split(" ") if w and len(w) > 2]  # Filter very short words
    
    # Add normalized date and duration keywords if available
    if job_data:
        if job_data.get('dateKeyword'):
            words.append(job_data['dateKeyword'])
        if job_data.get('durationKeyword'):
            words.append(job_data['durationKeyword'])
            
            # Check if duration maps to "half" or "full"
            duration_keyword = job_data['durationKeyword']
            half_day_durations = [
                "0100", "0115", "0130", "0145",
                "0200", "0215", "0230", "0245",
                "0300", "0315", "0330", "0345",
                "0400"
            ]
            full_day_durations = [
                "0415", "0430", "0445",
                "0500", "0515", "0530", "0545",
                "0600", "0615", "0630", "0645",
                "0700", "0715", "0730", "0745",
                "0800", "0815", "0830", "0845",
                "0900", "0915"
            ]
            
            if duration_keyword in half_day_durations:
                words.append("half")
            elif duration_keyword in full_day_durations:
                words.append("full")
    
    return sorted(set(words))

def generate_event_id(district_id: str, job_id: str, date: str, start_time: str, location: str) -> str:
    """
    Generate stable hash for deduplication.
    Uses district_id, job_id, date, start_time, and location.
    """
    combined = f"{district_id}|{job_id}|{date}|{start_time}|{location}"
    return hashlib.sha256(combined.encode()).hexdigest()

def normalize_date(date_str: str) -> str:
    """
    Normalize date string to keyword format (e.g., "Mon, 2/5/2026" -> "2_5_2026")
    Removes leading zeros from month and day.
    """
    # Remove weekday prefix if present (e.g., "Mon, " or "Monday, ")
    cleaned = date_str.strip()
    if ',' in cleaned:
        cleaned = cleaned.split(',')[-1].strip()
    
    # Handle formats like "2/5/2026" or "02/05/2026"
    if '/' in cleaned:
        parts = cleaned.split('/')
        if len(parts) == 3:
            try:
                month = int(parts[0])  # Remove leading zero
                day = int(parts[1])    # Remove leading zero
                year = parts[2]
                return f"{month}_{day}_{year}"
            except (ValueError, IndexError):
                pass
    
    # Handle ISO format "2024-01-15" -> "1_15_2024"
    if '-' in cleaned and len(cleaned) >= 10:
        parts = cleaned.split('-')
        if len(parts) == 3:
            try:
                year = parts[0]
                month = int(parts[1])  # Remove leading zero
                day = int(parts[2])     # Remove leading zero
                return f"{month}_{day}_{year}"
            except (ValueError, IndexError):
                pass
    
    # Fallback: replace slashes and dashes with underscores
    return cleaned.replace('/', '_').replace('-', '_')

def normalize_duration(duration_str: str) -> str:
    """
    Normalize duration string to 4-digit format (e.g., "01:15" -> "0115")
    Also handles text formats like "Full Day", "Half Day"
    """
    cleaned = duration_str.strip().lower()
    
    # Handle text formats first
    if 'full' in cleaned and 'day' in cleaned:
        # Full day - return a representative time (e.g., "0800" for 8 hours)
        # This will match full day duration range
        return "0800"  # 8:00 AM - represents full day
    elif 'half' in cleaned and 'day' in cleaned:
        # Half day - return a representative time (e.g., "0400" for 4 hours)
        # This will match half day duration range
        return "0400"  # 4:00 - represents half day
    
    # Handle time formats like "01:15", "1:15", etc.
    if ':' in cleaned:
        parts = cleaned.split(':')
        if len(parts) >= 2:
            try:
                hours = int(parts[0].strip())
                minutes = int(parts[1].strip().split(' ')[0])
                return f"{hours:02d}{minutes:02d}"
            except (ValueError, IndexError):
                pass
    
    # Extract numbers and pad to 4 digits
    numbers = ''.join(c for c in cleaned if c.isdigit())
    if numbers:
        return numbers.zfill(4)[:4]
    
    return cleaned

def parse_job_block(block: str) -> Optional[dict]:
    """
    Parse a job block string into structured data.
    Returns None if parsing fails.
    Normalizes dates and durations for keyword matching.
    """
    lines = [ln.strip() for ln in block.splitlines() if ln.strip()]
    
    job_data = {
        'confirmationNumber': '',
        'teacher': '',
        'title': '',
        'date': '',
        'dateKeyword': '',  # Normalized date for keyword matching
        'startTime': '',
        'endTime': '',
        'duration': '',
        'durationKeyword': '',  # Normalized duration for keyword matching
        'location': '',
    }
    
    for line in lines:
        line_upper = line.upper()
        if line_upper.startswith('CONFIRMATION #'):
            job_data['confirmationNumber'] = line.split('#', 1)[1].strip()
        elif line_upper.startswith('TEACHER:'):
            job_data['teacher'] = line.split(':', 1)[1].strip()
        elif line_upper.startswith('TITLE:'):
            job_data['title'] = line.split(':', 1)[1].strip()
        elif line_upper.startswith('DATE:'):
            date_str = line.split(':', 1)[1].strip()
            job_data['date'] = date_str
            job_data['dateKeyword'] = normalize_date(date_str)
        elif line_upper.startswith('TIME:'):
            time_part = line.split(':', 1)[1].strip()
            if ' - ' in time_part:
                parts = time_part.split(' - ', 1)
                job_data['startTime'] = parts[0].strip()
                job_data['endTime'] = parts[1].strip() if len(parts) > 1 else ''
            else:
                job_data['startTime'] = time_part
        elif line_upper.startswith('DURATION:'):
            duration_str = line.split(':', 1)[1].strip()
            job_data['duration'] = duration_str
            job_data['durationKeyword'] = normalize_duration(duration_str)
        elif line_upper.startswith('LOCATION:'):
            job_data['location'] = line.split(':', 1)[1].strip()
    
    # Require at least confirmation number and date
    if not job_data['confirmationNumber'] or not job_data['date']:
        return None
    
    return job_data

def construct_job_url(job_id: str) -> str:
    """
    Construct job URL from job ID.
    Adjust this based on actual Frontline URL structure.
    """
    # This is a placeholder - adjust based on actual Frontline URL pattern
    base_url = "https://absencesub.frontlineeducation.com/Substitute/Home"
    return f"{base_url}#/job/{job_id}"

def publish_job_event(job_block: str) -> bool:
    """
    Parse job block and publish to Firestore if not already exists.
    Returns True if published, False if skipped (already exists).
    """
    job_data = parse_job_block(job_block)
    if not job_data:
        log(f"[publish] Failed to parse job block, skipping")
        return False
    
    job_id = job_data['confirmationNumber']
    date = job_data['date']
    start_time = job_data['startTime']
    location = job_data['location']
    
    # Generate stable event ID
    event_id = generate_event_id(DISTRICT_ID, job_id, date, start_time, location)
    
    # Check if event already exists
    event_ref = db.collection('job_events').document(event_id)
    try:
        if event_ref.get().exists:
            log(f"[publish] Event {event_id[:16]}... already exists, skipping")
            return False
    except Exception as e:
        log(f"[publish] Error checking event existence: {e}")
        return False
    
    # Extract keywords from snapshot text (including normalized date/duration)
    keywords = extract_keywords(job_block, job_data)
    
    # Construct job URL
    job_url = construct_job_url(job_id)
    
    # Build job event document
    job_event = {
        'source': 'frontline',
        'controllerId': CONTROLLER_ID,
        'districtId': DISTRICT_ID,
        'jobId': job_id,
        'jobUrl': job_url,
        'snapshotText': job_block,
        'keywords': keywords,
        'createdAt': firestore.SERVER_TIMESTAMP,
        'jobData': job_data,
    }
    
    # Write to Firestore (critical - must succeed)
    try:
        event_ref.set(job_event)
        log(f"[publish] ✅ Published job event: {event_id[:16]}... (jobId: {job_id})")
    except Exception as e:
        log(f"[publish] ❌ Error publishing event to Firestore: {e}")
        return False
    
    # Send NTFY notification (non-critical - don't fail if this errors)
    # This is separate so Firestore write success is independent of notification
    try:
        message = (
            f"🆕 NEW FRONTLINE JOB\n\n"
            f"{job_block}\n\n"
            f"Controller: {CONTROLLER_ID}\n"
            f"District: {DISTRICT_ID}"
        )
        notify(message)
        log(f"[notify] Sent NTFY notification for job {job_id} to {get_ntfy_topic()}")
    except Exception as e:
        # Log but don't fail - job event was already written to Firestore
        log(f"[notify] Warning: Failed to send NTFY notification (job event still recorded): {e}")
    
    return True

# ---------------------------------------------------------------------
# SCRAPING JOB BLOCKS
# ---------------------------------------------------------------------

async def try_extract_available_job_blocks(page) -> list[str]:
    """
    DOM-based extraction from Frontline's real job containers:
    #availableJobs tbody.job (each has id=<confirmation_number>)
    """
    jobs = page.locator("#availableJobs tbody.job")
    try:
        count = await jobs.count()
    except Exception:
        count = 0

    job_blocks: list[str] = []

    for i in range(count):
        job = jobs.nth(i)

        # confirmation/job id is literally the tbody id
        job_id = ""
        try:
            job_id = (await job.get_attribute("id")) or ""
        except Exception:
            job_id = ""

        async def safe_text(locator_str: str) -> str:
            try:
                loc = job.locator(locator_str).first
                if await loc.count() == 0:
                    return ""
                t = (await loc.inner_text()).strip()
                return t
            except Exception:
                return ""

        teacher = await safe_text("span.name")
        title = await safe_text("span.title")
        conf_num = await safe_text("span.confNum")
        item_date = await safe_text("span.itemDate")
        start_time = await safe_text("span.startTime")
        end_time = await safe_text("span.endTime")
        duration = await safe_text("span.durationName")
        location = await safe_text("div.locationName")

        # fallback duration if durationName isn't what the UI shows
        if not duration:
            try:
                dur_cell = job.locator("tr.detail td.duration").first
                if await dur_cell.count() > 0:
                    duration = " ".join((await dur_cell.inner_text()).split())
            except Exception:
                pass

        block_lines = []
        if job_id or conf_num:
            block_lines.append(f"CONFIRMATION #{conf_num or job_id}")
        if teacher:
            block_lines.append(f"TEACHER: {teacher}")
        if title:
            block_lines.append(f"TITLE: {title}")
        if item_date:
            block_lines.append(f"DATE: {item_date}")
        if start_time or end_time:
            block_lines.append(f"TIME: {start_time} - {end_time}".strip())
        if duration:
            block_lines.append(f"DURATION: {duration}")
        if location:
            block_lines.append(f"LOCATION: {location}")

        block = "\n".join([ln for ln in block_lines if ln.strip()])

        # If we got *nothing*, skip
        if not block.strip():
            continue

        job_blocks.append(block)

    return job_blocks


async def get_available_jobs_snapshot(page) -> str:
    """
    High-level extraction:
    - Try to parse available jobs.
    - If we find at least one job, return them joined by '\n\n'.
    - If we do not find jobs but the page says "no available assignments",
      return sentinel "NO_AVAILABLE_JOBS".
    - If we see nothing at all (blind), also return "NO_AVAILABLE_JOBS".
    """
    job_blocks = await try_extract_available_job_blocks(page)

    if job_blocks:
        unique_blocks: list[str] = []
        for block in job_blocks:
            if block not in unique_blocks:
                unique_blocks.append(block)
        return "\n\n".join(unique_blocks)

    # No jobs found - check for "no jobs" message using smaller, targeted selectors
    # Avoid expensive body.inner_text() call
    no_jobs_text = ""
    try:
        # Try common selectors for "no jobs" messages first
        no_jobs_selectors = [
            "#availableJobs .no-jobs",
            "#availableJobs .empty",
            "#availableJobs .no-available",
            ".no-available-jobs",
            ".empty-jobs",
            "[class*='no-jobs']",
            "[class*='no-available']",
            "[id*='no-jobs']",
        ]
        
        for selector in no_jobs_selectors:
            try:
                element = page.locator(selector).first
                if await element.count() > 0:
                    no_jobs_text = await element.inner_text()
                    break
            except Exception:
                continue
        
        # If no specific selector found, try the availableJobs container (smaller than body)
        if not no_jobs_text:
            try:
                available_jobs_container = page.locator("#availableJobs").first
                if await available_jobs_container.count() > 0:
                    no_jobs_text = await available_jobs_container.inner_text()
            except Exception:
                pass
    except Exception:
        pass

    # Check if any "no jobs" markers are in the text
    if no_jobs_text:
        no_jobs_flat = " ".join(no_jobs_text.split())
        for marker in NO_JOBS_MARKERS:
            if marker in no_jobs_flat:
                return "NO_AVAILABLE_JOBS"

    # Fallback: if we can't find jobs and can't find "no jobs" message, assume no jobs
    return "NO_AVAILABLE_JOBS"

# ---------------------------------------------------------------------
# AUTH / MAIN LOOP
# ---------------------------------------------------------------------

async def ensure_logged_in(page, username: str, password: str) -> bool:
    """
    Attempt to log in IF we are on the Frontline login domain.
    Return True if we *appear* logged in (i.e. no longer on login domain),
    else False.
    """
    if "login.frontlineeducation.com" not in page.url:
        print("[auth] Already not on login domain; assuming logged in.")
        return True

    print("[auth] On login page, attempting credential fill...")

    user_input = page.locator(
        'input[type="email"], input[name*="user"], input[type="text"], '
        'input[name="username"], input#username'
    ).first
    pass_input = page.locator(
        'input[type="password"], input[name="password"], input#password'
    ).first

    try:
        await user_input.wait_for(timeout=5000)
        await pass_input.wait_for(timeout=5000)
    except Exception:
        print("[auth] No username/password fields visible (likely SSO).")
        return False

    try:
        await user_input.fill(username)
        await pass_input.fill(password)
        print("[auth] Filled username/password.")
        
        # Dispatch input/change events to ensure form validation triggers (like old code)
        try:
            await user_input.evaluate("el => { el.dispatchEvent(new Event('input', {bubbles: true})); el.dispatchEvent(new Event('change', {bubbles: true})); }")
            await pass_input.evaluate("el => { el.dispatchEvent(new Event('input', {bubbles: true})); el.dispatchEvent(new Event('change', {bubbles: true})); }")
        except Exception:
            pass  # Events are optional, don't fail if they don't work
    except Exception as e:
        print(f"[auth] Could not fill login fields: {e}")
        return False

    submit_btn = page.locator(
        'button[type="submit"], '
        'button:has-text("Sign in"), button:has-text("Sign In"), '
        'button:has-text("Log in"), button:has-text("Log In"), '
        'input[type="submit"]'
    ).first

    if await submit_btn.count() > 0:
        print("[auth] Clicking submit button...")
        try:
            await submit_btn.click()
        except Exception:
            print("[auth] Click failed; pressing Enter on password instead.")
            await pass_input.press("Enter")
    else:
        print("[auth] No submit button; pressing Enter on password.")
        await pass_input.press("Enter")

    # Wait for page load - use "load" like old working code (more conservative)
    # "networkidle" can be too aggressive and trigger rate limits
    try:
        await page.wait_for_load_state("load", timeout=30000)
    except Exception:
        # If load times out, at least wait for DOM
        try:
            await page.wait_for_load_state("domcontentloaded", timeout=5000)
        except Exception:
            pass

    print(f"[auth] After login attempt, page.url={page.url}")
    return ("login.frontlineeducation.com" not in page.url)


async def main() -> None:
    username = os.getenv("FRONTLINE_USERNAME")
    password = os.getenv("FRONTLINE_PASSWORD")
    if not username or not password:
        print("ERROR: Missing FRONTLINE_USERNAME or FRONTLINE_PASSWORD")
        print()
        print(
            "Required environment variables:\n"
            "  - FRONTLINE_USERNAME\n"
            "  - FRONTLINE_PASSWORD\n"
            "  - CONTROLLER_ID (controller_1 through controller_5)\n"
            "  - DISTRICT_ID\n"
            "  - FIREBASE_PROJECT_ID\n"
            "  - FIREBASE_CREDENTIALS_PATH\n"
        )
        sys.exit(1)

    log(f"[init] Controller: {CONTROLLER_ID}, District: {DISTRICT_ID}")
    log(f"[init] Firebase Project: {FIREBASE_PROJECT_ID}")

    relogin_failures = 0
    MAX_RELOGIN_FAILURES = 5

    # Apply initial offset for this controller
    offset = get_scraper_offset()
    if offset > 0:
        log(f"[init] Applying {offset}s offset for {CONTROLLER_ID}")
        await asyncio.sleep(offset)

    async with async_playwright() as p:
        # Try to load saved browser context (cookies from manual auth)
        # This allows us to bypass SSO by using a pre-authenticated session
        storage_state_path = os.getenv("STORAGE_STATE_PATH", f"/opt/frontline-watcher/storage_state_{CONTROLLER_ID}.json")
        context_options = {}
        
        if os.path.exists(storage_state_path):
            try:
                context_options["storage_state"] = storage_state_path
                log(f"[auth] Loading saved browser context from {storage_state_path}")
            except Exception as e:
                log(f"[auth] Warning: Could not load saved context: {e}")
        else:
            log(f"[auth] No saved browser context found at {storage_state_path}, will use username/password")
        
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(**context_options)
        page = await context.new_page()
        page.on("dialog", lambda d: asyncio.create_task(d.accept()))

        await page.goto(JOBS_URL)
        await page.wait_for_load_state("domcontentloaded")

        if "login.frontlineeducation.com" in page.url:
            print("[auth] Not logged in at start, attempting login...")
            # If we have saved context but still on login page, it may have expired
            if os.path.exists(storage_state_path):
                log(f"[auth] Saved context expired, attempting fresh login...")
            
            await page.goto(LOGIN_URL, wait_until="domcontentloaded", timeout=60000)
            ok = await ensure_logged_in(page, username, password)
            if ok:
                print("[auth] Login appears successful, returning to jobs page.")
                # Save the authenticated context for next time
                try:
                    await context.storage_state(path=storage_state_path)
                    log(f"[auth] Saved authenticated context to {storage_state_path}")
                except Exception as e:
                    log(f"[auth] Warning: Could not save context: {e}")
                
                await page.goto(JOBS_URL, wait_until="load", timeout=60000)
            else:
                log("[auth] ❌ Login failed - SSO/captcha may be blocking. Cannot proceed.")
                raise Exception("Login failed - SSO/captcha blocking automated login")
        else:
            log("[auth] ✅ Already logged in (using saved context or existing session)")

        await page.wait_for_load_state("load", timeout=60000)

        baseline = await get_available_jobs_snapshot(page)
        log("[*] Monitoring started.")
        log(f"[available_jobs baseline]:\n{baseline[:500]}")
        
        # Send startup notification
        startup_message = f"🚀 Frontline watcher started\nController: {CONTROLLER_ID}\nDistrict: {DISTRICT_ID}\nNTFY Topic: {get_ntfy_topic()}"
        notify(startup_message)
        log(f"[notify] Sent startup notification to {get_ntfy_topic()}")

        # Track which jobs we've already published in this session (bounded LRU cache)
        # Firestore already handles deduplication, but this helps avoid redundant checks
        # Limit to last 100 jobs to prevent unbounded growth
        MAX_SESSION_CACHE = 100
        published_job_ids = set()

        while True:
            try:
                await page.reload(wait_until="domcontentloaded")
            except PWTimeout:
                log("[!] reload timeout")
            except Exception as e:
                log(f"[!] reload error: {e}")
                await asyncio.sleep(2)

            if "login.frontlineeducation.com" in page.url:
                relogin_failures += 1
                print(f"[auth] Session expired. Re-auth... (failures={relogin_failures}/{MAX_RELOGIN_FAILURES})")
                
                # Exponential backoff: wait longer with each failure to avoid hammering the site
                # This prevents triggering rate limits when blocked
                backoff_delay = min(60 * (2 ** (relogin_failures - 1)), 300)  # 1min, 2min, 4min, 8min, max 5min
                if relogin_failures > 1:
                    log(f"[auth] Backing off for {backoff_delay}s before retry (exponential backoff)")
                    await asyncio.sleep(backoff_delay)

                try:
                    await page.goto(LOGIN_URL, wait_until="domcontentloaded", timeout=60000)
                except Exception as e:
                    print(f"[auth] goto(LOGIN_URL) failed: {e}")
                    if relogin_failures >= MAX_RELOGIN_FAILURES:
                        log("🔥 Frontline watcher: login page keeps timing out. Stopping to avoid rate limiting.")
                        notify("🔥 Frontline watcher: login page keeps timing out. Stopping to avoid rate limiting.")
                        raise Exception("Max relogin failures reached - stopping to avoid rate limiting")
                    # Already waited with backoff above, just continue
                    continue

                ok = await ensure_logged_in(page, username, password)

                if ok:
                    print("[auth] Login attempt looks OK; going back to jobs page.")
                    try:
                        await page.goto(JOBS_URL, wait_until="load", timeout=60000)
                        relogin_failures = 0  # reset on success
                        log("[auth] ✅ Successfully re-authenticated")
                    except Exception as e:
                        print(f"[auth] goto(JOBS_URL) failed after login: {e}")
                        # Don't increment failure count here - login succeeded, just navigation failed
                        # Wait a bit before retrying
                        await asyncio.sleep(10)
                        continue
                else:
                    print("[auth] Re-login failed / still gated by SSO.")
                    if relogin_failures >= MAX_RELOGIN_FAILURES:
                        log("🔥 Frontline watcher: blocked by SSO/captcha after multiple attempts. Stopping to avoid rate limiting.")
                        notify("🔥 Frontline watcher: blocked by SSO/captcha. Stopping to avoid rate limiting.")
                        raise Exception("Max relogin failures reached - SSO/captcha blocking login, stopping to avoid rate limiting")
                    # Backoff already handled above, just continue
                    continue

            current = await get_available_jobs_snapshot(page)
            
            if current != "NO_AVAILABLE_JOBS":
                # Extract individual job blocks
                job_blocks = [b.strip() for b in current.split("\n\n") if b.strip()]
                
                log(f"[monitor] Found {len(job_blocks)} job(s) on page")
                
                for block in job_blocks:
                    # Parse to get job ID for tracking
                    job_data = parse_job_block(block)
                    if job_data and job_data['confirmationNumber']:
                        job_id = job_data['confirmationNumber']
                        
                        # Skip if we've already published this job in this session
                        if job_id in published_job_ids:
                            log(f"[monitor] Job {job_id} already processed in this session, skipping")
                            continue
                        
                        # Try to publish (this will send NTFY notification if it's a new job)
                        published = publish_job_event(block)
                        if published:
                            # Add to session cache (bounded LRU)
                            if len(published_job_ids) >= MAX_SESSION_CACHE:
                                # Remove oldest entry (simple FIFO since we can't track access order easily)
                                # In practice, Firestore deduplication handles this, so we just clear when full
                                published_job_ids.clear()
                            published_job_ids.add(job_id)
                            log(f"[publish] ✅ Published and notified for job {job_id}")
                        else:
                            log(f"[publish] Job {job_id} already exists in Firestore, skipping notification")
                    else:
                        log(f"[publish] Could not parse job block, skipping")
            
            # Update baseline
            baseline = current

            # Determine delay based on hot window and configured interval
            SCRAPE_INTERVAL = int(os.getenv("SCRAPE_INTERVAL_SECONDS", "15"))
            if should_run_aggressive():
                # Use configured interval (with small random variation)
                delay = SCRAPE_INTERVAL + random.uniform(-2, 2)
            else:
                # Slower outside hot windows (5x the interval)
                delay = SCRAPE_INTERVAL * 5

            log(f"(sleeping {delay:.2f}s)")
            await asyncio.sleep(delay)


if __name__ == "__main__":
    asyncio.run(main())

