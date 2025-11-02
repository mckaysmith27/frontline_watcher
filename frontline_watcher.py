'''
This works 
'''

import asyncio
import difflib
import os
import sys
import random
import requests
from playwright.async_api import async_playwright, TimeoutError as PWTimeout

LOGIN_URL = (
    "https://login.frontlineeducation.com/login"
    "?signin=a6740188d37bd24dc70d4748ad55028e"
    "&productId=ABSMGMT&clientId=ABSMGMT#/login"
)

JOBS_URL = "https://absencesub.frontlineeducation.com/Substitute/Home"

# Randomized poll delay bounds (seconds)
MIN_DELAY = 16
MAX_DELAY = 31

def get_random_delay():
    """Return a random delay between MIN_DELAY and MAX_DELAY seconds."""
    return random.uniform(MIN_DELAY, MAX_DELAY)

def notify(msg: str):
    """Send a push notification to ntfy if NTFY_TOPIC is set."""
    topic = os.getenv("NTFY_TOPIC")
    if topic:
        try:
            requests.post(
                f"https://ntfy.sh/{topic}",
                data=msg.encode("utf-8"),
                timeout=5
            )
        except Exception:
            # swallow notification errors so the watcher keeps running
            pass

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
TAB_EXCLUDE_KEYWORDS = [
    "Past Jobs",
    "Scheduled Jobs",
    "History",
    "Preferences",
    "Resource Library",
    "RECENT NOTIFICATIONS",
    "Substitute",        # header profile junk, not a row
    "Alpine School District",  # district header junk
    "SUN MON TUE WED THU FRI SAT",  # calendar junk
]


def block_is_obviously_junk(text_block: str) -> bool:
    """
    True if this block is nav/calendar/profile/etc.
    """
    t = " ".join(text_block.split())
    for bad in TAB_EXCLUDE_KEYWORDS:
        if bad in t:
            return True
    return False


def block_is_available_jobs_headerish(text_block: str) -> bool:
    """
    True if the block looks like the Available Jobs table area.
    It should contain table headers and not be obviously junk.
    """
    t = " ".join(text_block.split())
    if block_is_obviously_junk(t):
        return False
    # Must contain "Date / Time / Duration / Location" style table labels
    # or say "Available Jobs"
    header_hits = 0
    for h in AVAILABLE_JOBS_HEADERS:
        if h in t:
            header_hits += 1
    return header_hits >= 2  # relaxed but targeted


def normalize_lines(text: str) -> str:
    """
    Collapse whitespace per line and drop empty lines.
    """
    lines = [" ".join(line.split()) for line in text.splitlines() if line.strip()]
    l = "\n".join(lines)
    return l

def block_is_definitely_past_job(text_block: str) -> bool:
    """
    Returns True if this block is clearly from 'Past Jobs' / history instead of
    the active 'Available Jobs' tab.

    We key off phrases that only show up after a job is already worked,
    not in a fresh open assignment.
    """
    t = " ".join(text_block.split())

    PAST_MARKERS = [
        "Leave Feedback",
        "View Feedback",
        "Confirmation #",
        "Hide Details",  # this is usually part of a details/feedback panel
    ]

    # If the block tells you to leave/view feedback, it's not an open job.
    for m in PAST_MARKERS:
        if m in t:
            return True

    # If it literally says "No data to display", that table isn't active jobs.
    if "No data to display" in t:
        return True

    return False


async def try_extract_available_jobs_blocks(page):
    """
    Pull only the 'Available Jobs' block(s):
    - Walk likely containers (<table>, <section>, <div>)
    - Identify ones that look like the Available Jobs area
    - Extract rows that look like live offers (not history / not ghost fragments)
    - Return each job as its own multiline string

    Returns:
        list[str] of job-blocks
        OR [] if we don't see anything that looks like active job rows.
    """

    POSSIBLE_CONTAINERS = ["table", "section", "div"]
    job_blocks = []

    # helper: does a finished job block look like a real, live posting?
    # require (1) a weekday/date stamp like "Mon," "Tue," "Wed," etc.
    # because live offers show explicit day/date ranges:
    #   "Thu, 11/6/2025 7:45 AM - 2:15 PM Full Day"
    # the ghost Liberty Hills block did NOT have "Thu," / "Fri," etc.
    def looks_like_real_available_job(jb: str) -> bool:
        weekday_signatures = [
            "Mon,", "Tue,", "Wed,", "Thu,", "Fri,", "Sat,", "Sun,",
        ]
        has_weekday = any(sig in jb for sig in weekday_signatures)
        if not has_weekday:
            return False
        return True

    for tag in POSSIBLE_CONTAINERS:
        nodes = page.locator(tag)
        try:
            ncount = await nodes.count()
        except Exception:
            ncount = 0

        for i in range(min(ncount, 200)):
            # grab raw text for this container
            try:
                raw = await nodes.nth(i).inner_text()
            except Exception:
                continue
            if not raw or not raw.strip():
                continue

            cleaned = normalize_lines(raw)

            # Skip obvious junk like nav/calendar/past jobs tables
            if block_is_obviously_junk(cleaned):
                continue

            # Skip containers that don't even look like Available Jobs headers
            if not block_is_available_jobs_headerish(cleaned):
                continue

            # We'll walk line-by-line and build job blocks.
            lines = cleaned.split("\n")

            current_job_lines = []
            current_job_has_past_marker = False
            parsed_jobs_from_this_container = []

            def flush_job():
                nonlocal current_job_lines, current_job_has_past_marker
                if not current_job_lines:
                    current_job_has_past_marker = False
                    return

                jb = "\n".join(current_job_lines).strip()

                # --- FILTERS TO REJECT NON-LIVE JOBS ---

                # empty/useless
                if not jb:
                    pass

                # explicit "no jobs"/header content
                elif any(marker in jb for marker in NO_JOBS_MARKERS):
                    pass

                # just table headers
                elif "Date" in jb and "Time" in jb and "Duration" in jb and "Location" in jb:
                    pass

                # labeled as "Past Jobs"
                elif "Past Jobs" in jb:
                    pass

                # had past/feedback markers at any point
                elif current_job_has_past_marker:
                    pass

                # NEW RULE:
                # must look like a real available job by containing a weekday/date stamp
                elif not looks_like_real_available_job(jb):
                    # this kills orphan fragments like the Liberty Hills block
                    pass

                else:
                    parsed_jobs_from_this_container.append(jb)

                # reset
                current_job_lines = []
                current_job_has_past_marker = False

            for line in lines:
                line_stripped = line.strip()

                # mark block as contaminated if it's obviously past / feedback
                if block_is_definitely_past_job(line_stripped):
                    current_job_has_past_marker = True

                # Decide if line is part of a live assignment row
                looks_like_time = (" AM" in line_stripped) or (" PM" in line_stripped)
                looks_like_schoolish = (
                    "Elementary" in line_stripped
                    or "Middle" in line_stripped
                    or "High School" in line_stripped
                    or "Teacher" in line_stripped
                    or "Grade" in line_stripped
                )
                is_tab_label = any(k in line_stripped for k in TAB_EXCLUDE_KEYWORDS)

                if (looks_like_time or looks_like_schoolish) and not is_tab_label:
                    # still building a job block
                    current_job_lines.append(line_stripped)
                else:
                    # boundary -> close out previous block
                    flush_job()

            # flush tail block
            flush_job()

            # merge deduped, filtered jobs from this container
            for jb in parsed_jobs_from_this_container:
                if jb not in job_blocks:
                    job_blocks.append(jb)

    return job_blocks

async def extract_available_jobs_snapshot(page):
    """
    High-level extraction:
    - Try to parse available jobs.
    - If we find at least one job, return them joined by '\n\n'.
    - If we do not find jobs but the page says "no available assignments", return sentinel "NO_AVAILABLE_JOBS".
    - If we see nothing at all (blind), also return "NO_AVAILABLE_JOBS".
    """

    job_blocks = await try_extract_available_jobs_blocks(page)

    if job_blocks:
        # Deduplicate exact matches just in case
        uniq = []
        for b in job_blocks:
            if b not in uniq:
                uniq.append(b)
        return "\n\n".join(uniq)

    # No job blocks. Let's see if the page is explicitly telling us "no jobs".
    body_text = ""
    try:
        body_text = await page.inner_text("body")
    except Exception:
        pass

    body_flat = " ".join(body_text.split())

    for marker in NO_JOBS_MARKERS:
        if marker in body_flat:
            return "NO_AVAILABLE_JOBS"

    # Fallback: if it's clean but empty, call it "NO_AVAILABLE_JOBS"
    return "NO_AVAILABLE_JOBS"


def summarize_change(before_snapshot: str, after_snapshot: str) -> str:
    """
    Decide what message to send based on the transition.

    - before = NO_AVAILABLE_JOBS, after = jobs
      => "NEW FRONTLINE JOB"
    - before = jobs, after = NO_AVAILABLE_JOBS
      => "PREVIOUS JOB HAS EXPIRED"
    - both have jobs but content changed
      => "NEW FRONTLINE JOB" (treat as new listing / changed listing)
    """

    before_none = (before_snapshot == "NO_AVAILABLE_JOBS")
    after_none = (after_snapshot == "NO_AVAILABLE_JOBS")

    if before_none and not after_none:
        return "NEW FRONTLINE JOB"

    if (not before_none) and after_none:
        return "PREVIOUS JOB HAS EXPIRED"

    if (not before_none) and (not after_none) and (before_snapshot != after_snapshot):
        return "NEW FRONTLINE JOB"

    # shouldn't call this if nothing changed, but safe fallback
    return "UPDATE"


def diff_for_logs(before_snapshot: str, after_snapshot: str) -> str:
    """
    Returns a unified diff string for logging only.
    """
    diff_lines = []
    for line in difflib.unified_diff(
        before_snapshot.splitlines(),
        after_snapshot.splitlines(),
        fromfile="before",
        tofile="after",
        lineterm=""
    ):
        diff_lines.append(line)
    return "\n".join(diff_lines)


async def ensure_logged_in(page, username, password):
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
        'input[type="email"], input[name*="user"], input[type="text"], input[name="username"], input#username'
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

    try:
        await page.wait_for_load_state("networkidle", timeout=15000)
    except Exception:
        pass

    print(f"[auth] After login attempt, page.url={page.url}")
    return ("login.frontlineeducation.com" not in page.url)


async def main():
    username = os.getenv("FRONTLINE_USERNAME")
    password = os.getenv("FRONTLINE_PASSWORD")
    if not username or not password:
        print("Missing credentials")
        sys.exit(1)

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context()
        page = await ctx.new_page()

        # Go to jobs page first
        await page.goto(JOBS_URL)
        await page.wait_for_load_state("domcontentloaded")

        # If we got bounced to login, attempt to auth
        if "login.frontlineeducation.com" in page.url:
            print("[auth] Not logged in at start, attempting login...")
            await page.goto(LOGIN_URL)
            ok = await ensure_logged_in(page, username, password)
            if ok:
                print("[auth] Login appears successful, returning to jobs page.")
                await page.goto(JOBS_URL)

        await page.wait_for_load_state("networkidle")

        # snapshot at start (baseline of Available Jobs tab only)
        baseline = await extract_available_jobs_snapshot(page)
        print("[*] Monitoring started.")
        print(f"[available_jobs baseline]:\n{baseline[:500]}")
        notify("Frontline watcher started")

        while True:
            # 1. Refresh page
            try:
                await page.reload(wait_until="networkidle")
            except PWTimeout:
                print("[!] reload timeout")

            # 2. Re-auth mid-run if kicked out
            if "login.frontlineeducation.com" in page.url:
                print("[auth] Session expired. Re-auth...")
                await page.goto(LOGIN_URL)
                ok = await ensure_logged_in(page, username, password)
                if ok:
                    print("[auth] Re-login appears successful, going back to jobs.")
                    await page.goto(JOBS_URL)
                    await page.wait_for_load_state("networkidle")
                else:
                    print("[auth] Re-login failed / still gated by SSO.")

            # 3. Scrape the Available Jobs tab snapshot only
            current = await extract_available_jobs_snapshot(page)
            print(f"[available_jobs now]:\n{current[:500]}")

            # 4. Compare and alert if changed
            if current != baseline:
                change_type = summarize_change(baseline, current)
                print("\n=== CHANGE DETECTED ===")
                print(f"[change_type] {change_type}")
                print(diff_for_logs(baseline, current))

                if change_type == "NEW FRONTLINE JOB":
                    # We treat 'current' as the source of truth now.
                    # Send the currently visible job(s).
                    message = f"🆕 NEW FRONTLINE JOB:\n{current}"
                    notify(message)
                    print(f"Sent notification: {message}")

                elif change_type == "PREVIOUS JOB HAS EXPIRED":
                    message = (
                        "⏳ PREVIOUS JOB HAS EXPIRED:\n"
                        "I'm sorry. There are no available assignments at the moment."
                    )
                    notify(message)
                    print(f"Sent notification: {message}")

                else:
                    # fallback / shouldn't really hit often
                    message = f"🔄 UPDATE:\n{current}"
                    notify(message)
                    print(f"Sent notification: {message}")

                baseline = current  # update baseline

            # 5. sleep random delay each loop
            delay = get_random_delay()
            print(f"(sleeping {delay:.2f}s)")
            await asyncio.sleep(delay)


if __name__ == "__main__":
    asyncio.run(main())
