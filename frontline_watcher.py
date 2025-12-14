import asyncio
import difflib
import os
import sys
import random
import requests
from typing import Optional
from playwright.async_api import async_playwright, TimeoutError as PWTimeout

#loads '.env'
from dotenv import load_dotenv
load_dotenv()

print("DEBUG JOB_INCLUDE_WORDS_ANY:", os.getenv("JOB_INCLUDE_WORDS_ANY"))
print("DEBUG JOB_INCLUDE_WORDS_COUNT:", os.getenv("JOB_INCLUDE_WORDS_COUNT"))
print("DEBUG JOB_EXCLUDE_WORDS_ANY:", os.getenv("JOB_EXCLUDE_WORDS_ANY"))
print("DEBUG JOB_EXCLUDE_WORDS_COUNT:", os.getenv("JOB_EXCLUDE_WORDS_COUNT"))

LOGIN_URL = (
    "https://login.frontlineeducation.com/login"
    "?signin=a6740188d37bd24dc70d4748ad55028e"
    "&productId=ABSMGMT&clientId=ABSMGMT#/login"
)

JOBS_URL = "https://absencesub.frontlineeducation.com/Substitute/Home"

# Randomized poll delay bounds (seconds)
MIN_DELAY = 16
MAX_DELAY = 31


def get_random_delay() -> float:
    """Return a random delay between MIN_DELAY and MAX_DELAY seconds."""
    return random.uniform(MIN_DELAY, MAX_DELAY)


def notify(message: str) -> None:
    """Send a push notification to ntfy if NTFY_TOPIC is set."""
    topic = os.getenv("NTFY_TOPIC")
    if topic:
        try:
            requests.post(
                f"https://ntfy.sh/{topic}",
                data=message.encode("utf-8"),
                timeout=5,
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
TAB_EXCLUDE_WORDS = [
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

# Common subject / role keywords we want to keep with each job
SUBJECT_WORDS = [
    "Math", "Algebra", "Geometry", "Calculus",
    "English", "Language Arts", "Reading", "Writing",
    "Science", "Biology", "Chemistry", "Physics",
    "History", "Social Studies",
    "PE", "Physical Education",
    "Fine Arts", "Art", "Choir", "Band", "Orchestra", "Music",
    "Health",
    "Spanish", "French", "German", "Chinese", "ESL", "ELL",
    "Special Education", "SPED",
]

# Weekday signatures used to recognize real job rows/blocks
WEEKDAY_WORDS = ["Mon,", "Tue,", "Wed,", "Thu,", "Fri,", "Sat,", "Sun,"]


# ---------------------------------------------------------------------
# ENV PARSING HELPERS
# ---------------------------------------------------------------------
def parse_word_list_env(env_name: str) -> list[str]:
    """
    Parse a comma-separated env var into a list of lowercase strings.

    Example:
        JOB_INCLUDE_WORDS_ANY="Fine Arts, Algebra"
        -> ["fine arts", "algebra"]
    """
    raw = os.getenv(env_name, "").strip()
    if not raw:
        return []
    return [part.strip().lower() for part in raw.split(",") if part.strip()]


def parse_int_env(env_name: str, default: int = 0) -> int:
    """
    Parse an integer env var. If missing or invalid, return default.
    """
    raw = os.getenv(env_name, "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def get_include_any_words() -> list[str]:
    """
    Notification whitelist (ANY match).

    JOB_INCLUDE_WORDS_ANY="Fine Arts, Algebra, English"
    -> only notify when at least one of these appears in the job text.
    """
    return parse_word_list_env("JOB_INCLUDE_WORDS_ANY")


def get_exclude_any_words() -> list[str]:
    """
    Notification blacklist (ANY match).

    JOB_EXCLUDE_WORDS_ANY="Kindergarten, Special Education"
    -> never notify if any of these appear in the job text.
    """
    return parse_word_list_env("JOB_EXCLUDE_WORDS_ANY")


def get_include_count_words() -> tuple[list[str], int]:
    """
    Count-based include filter.

    JOB_INCLUDE_WORDS_COUNT="Middle, High School, Teacher"
    JOB_INCLUDE_MIN_MATCHES=2

    -> Job must contain at least 2 of the words in the list.
    """
    words = parse_word_list_env("JOB_INCLUDE_WORDS_COUNT")
    min_matches = parse_int_env("JOB_INCLUDE_MIN_MATCHES", default=0)
    return words, max(min_matches, 0)


def get_exclude_count_words() -> tuple[list[str], int]:
    """
    Count-based exclude filter.

    JOB_EXCLUDE_WORDS_COUNT="Kindergarten, Resource, Aide"
    JOB_EXCLUDE_MIN_MATCHES=2

    -> Job is blocked if it contains at least 2 of these words.
    """
    words = parse_word_list_env("JOB_EXCLUDE_WORDS_COUNT")
    min_matches = parse_int_env("JOB_EXCLUDE_MIN_MATCHES", default=0)
    return words, max(min_matches, 0)


# ---------------------------------------------------------------------
# TEXT CLASSIFIERS
# ---------------------------------------------------------------------
def is_obviously_nav_or_chrome(text_block: str) -> bool:
    """
    True if this block is nav/calendar/profile/etc.
    """
    text_flat = " ".join(text_block.split())
    for word in TAB_EXCLUDE_WORDS:
        if word in text_flat:
            return True
    return False


def looks_like_available_jobs_container(text_block: str) -> bool:
    """
    True if the block looks like the Available Jobs table area.

    It should contain table headers and not be obviously junk.

    We also accept containers that look like real job rows:
    - contain a weekday/date signature (Mon,/Tue,/Wed,...)
    - and contain something school-ish (Teacher, Middle, etc.).
    """
    text_flat = " ".join(text_block.split())

    if is_obviously_nav_or_chrome(text_flat):
        return False

    # Original logic: strong signal from headers / "Available Jobs"
    header_hits = 0
    for header in AVAILABLE_JOBS_HEADERS:
        if header in text_flat:
            header_hits += 1
    if header_hits >= 2:
        return True

    # NEW: accept containers that look like real job content
    has_weekday = any(w in text_flat for w in WEEKDAY_WORDS)
    has_schoolish = any(
        token in text_flat
        for token in [
            "Elementary",
            "Middle",
            "High School",
            "Teacher",
            "Grade",
        ]
    )

    return has_weekday and has_schoolish


def normalize_lines(text: str) -> str:
    """
    Collapse whitespace per line and drop empty lines.
    """
    lines = [" ".join(line.split()) for line in text.splitlines() if line.strip()]
    return "\n".join(lines)


def is_definitely_past_job(text_block: str) -> bool:
    """
    Returns True if this block is clearly from 'Past Jobs' / history instead of
    the active 'Available Jobs' tab.
    """
    text_flat = " ".join(text_block.split())

    past_markers = [
        "Leave Feedback",
        "View Feedback",
        "Confirmation #",
        "Hide Details",  # this is usually part of a details/feedback panel
    ]

    for marker in past_markers:
        if marker in text_flat:
            return True

    if "No data to display" in text_flat:
        return True

    return False


# ---------------------------------------------------------------------
# SCRAPING JOB BLOCKS
# ---------------------------------------------------------------------
async def try_extract_available_job_blocks(page) -> list[str]:
    """
    Pull only the 'Available Jobs' block(s):

    - Walk likely containers (<table>, <section>, <div>)
    - Identify ones that look like the Available Jobs area
    - Extract rows that look like live offers (not history / not ghost fragments)
    - Return each job as its own multiline string
    """

    possible_containers = ["table", "section", "div"]
    job_blocks: list[str] = []

    def looks_like_real_job(job_text: str) -> bool:
        """Require a weekday/date stamp like 'Mon,' 'Tue,' etc."""
        return any(word in job_text for word in WEEKDAY_WORDS)

    for tag in possible_containers:
        nodes = page.locator(tag)
        try:
            count = await nodes.count()
        except Exception:
            count = 0

        for i in range(min(count, 200)):
            try:
                raw = await nodes.nth(i).inner_text()
            except Exception:
                continue
            if not raw or not raw.strip():
                continue

            cleaned = normalize_lines(raw)

            if is_obviously_nav_or_chrome(cleaned):
                continue
            if not looks_like_available_jobs_container(cleaned):
                continue

            lines = cleaned.split("\n")

            current_job_lines: list[str] = []
            current_job_is_past = False
            parsed_jobs_from_container: list[str] = []

            def flush_job() -> None:
                nonlocal current_job_lines, current_job_is_past
                if not current_job_lines:
                    current_job_is_past = False
                    return

                job_text = "\n".join(current_job_lines).strip()

                # --- FILTERS TO REJECT NON-LIVE JOBS ---
                if not job_text:
                    pass
                elif any(marker in job_text for marker in NO_JOBS_MARKERS):
                    pass
                elif (
                    "Date" in job_text
                    and "Time" in job_text
                    and "Duration" in job_text
                    and "Location" in job_text
                ):
                    # just table headers
                    pass
                elif "Past Jobs" in job_text:
                    pass
                elif current_job_is_past:
                    pass
                elif not looks_like_real_job(job_text):
                    pass
                else:
                    parsed_jobs_from_container.append(job_text)

                current_job_lines = []
                current_job_is_past = False

            for line in lines:
                line_stripped = line.strip()

                if is_definitely_past_job(line_stripped):
                    current_job_is_past = True

                looks_like_time = (" AM" in line_stripped) or (" PM" in line_stripped)

                looks_like_schoolish = (
                    "Elementary" in line_stripped
                    or "Middle" in line_stripped
                    or "High School" in line_stripped
                    or "Teacher" in line_stripped
                    or "Grade" in line_stripped
                    or any(subject in line_stripped for subject in SUBJECT_WORDS)
                )

                is_tab_label = any(word in line_stripped for word in TAB_EXCLUDE_WORDS)

                if (looks_like_time or looks_like_schoolish) and not is_tab_label:
                    current_job_lines.append(line_stripped)
                else:
                    flush_job()

            flush_job()

            for job_text in parsed_jobs_from_container:
                if job_text not in job_blocks:
                    job_blocks.append(job_text)

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

    body_text = ""
    try:
        body_text = await page.inner_text("body")
    except Exception:
        pass

    body_flat = " ".join(body_text.split())
    for marker in NO_JOBS_MARKERS:
        if marker in body_flat:
            return "NO_AVAILABLE_JOBS"

    return "NO_AVAILABLE_JOBS"


# ---------------------------------------------------------------------
# SNAPSHOT COMPARISON + FILTERING
# ---------------------------------------------------------------------
def summarize_change(before: str, after: str) -> str:
    """
    Decide what message to send based on the transition.
    """
    before_none = (before == "NO_AVAILABLE_JOBS")
    after_none = (after == "NO_AVAILABLE_JOBS")

    if before_none and not after_none:
        return "NEW FRONTLINE JOB"
    if (not before_none) and after_none:
        return "PREVIOUS JOB HAS EXPIRED"
    if (not before_none) and (not after_none) and (before != after):
        return "NEW FRONTLINE JOB"
    return "UPDATE"


def diff_for_logs(before: str, after: str) -> str:
    """
    Returns a unified diff string for logging only.
    """
    diff_lines = []
    for line in difflib.unified_diff(
        before.splitlines(),
        after.splitlines(),
        fromfile="before",
        tofile="after",
        lineterm="",
    ):
        diff_lines.append(line)
    return "\n".join(diff_lines)


def count_matches(words: list[str], text_lower: str) -> int:
    """
    Count how many DISTINCT words from `words` appear in `text_lower`.
    """
    if not words:
        return 0
    return sum(1 for w in words if w in text_lower)


def apply_job_filters_to_snapshot(
    snapshot: str,
    include_any_words: list[str],
    exclude_any_words: list[str],
    include_count_words: list[str],
    include_min_matches: int,
    exclude_count_words: list[str],
    exclude_min_matches: int,
) -> Optional[str]:

    """
    Apply all filters to a snapshot string.

    Rules:
      - If snapshot == "NO_AVAILABLE_JOBS", return it as-is.
      - Exclude ANY:
          If any word from exclude_any_words appears in the job text -> drop job.
      - Exclude COUNT:
          If count_matches(exclude_count_words) >= exclude_min_matches -> drop job.
      - Include ANY (whitelist):
          If include_any_words is non-empty and none appear -> drop job.
      - Include COUNT:
          If include_min_matches > 0 and
             count_matches(include_count_words) < include_min_matches -> drop job.
      - If no jobs remain after filtering, return None (no notification).
    """
    if snapshot == "NO_AVAILABLE_JOBS":
        return snapshot

    blocks = [b for b in snapshot.split("\n\n") if b.strip()]
    kept_blocks: list[str] = []

    for block in blocks:
        text_lower = block.lower()

        # 1) Blacklist by ANY-word
        if exclude_any_words and any(w in text_lower for w in exclude_any_words):
            continue

        # 2) Blacklist by COUNT
        if (
            exclude_min_matches > 0
            and exclude_count_words
            and count_matches(exclude_count_words, text_lower) >= exclude_min_matches
        ):
            continue

        # 3) Whitelist by ANY-word
        if include_any_words and not any(
            w in text_lower for w in include_any_words
        ):
            continue

        # 4) Whitelist by COUNT
        if (
            include_min_matches > 0
            and include_count_words
            and count_matches(include_count_words, text_lower) < include_min_matches
        ):
            continue

        kept_blocks.append(block)

    if not kept_blocks:
        return None

    return "\n\n".join(kept_blocks)


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

async def try_accept_first_visible_job(page) -> bool:
    """
    Click the first visible "Accept" button on the Available Jobs page,
    then (if a confirmation modal appears) click the modal's "Accept".
    Returns True if we clicked an Accept button, else False.
    """

    # ---- Step 1: click the primary Accept button (not Reject) ----
    accept_btn = page.locator('button:has-text("Accept")').first

    try:
        await accept_btn.wait_for(state="visible", timeout=3000)
        await accept_btn.click()
        print("[auto-accept] Clicked primary Accept button.")
    except Exception as e:
        print(f"[auto-accept] No visible primary Accept button found: {e}")
        return False

    # ---- Step 2: if a confirmation modal appears, click its Accept ----
    # We try a couple common modal patterns (role="dialog" and bootstrap-ish modals).
    modal_accept = page.locator(
        '[role="dialog"] button:has-text("Accept"), '
        '.modal button:has-text("Accept"), '
        '.modal-dialog button:has-text("Accept")'
    ).last

    try:
        # If it shows up, click it. If not, just move on.
        await modal_accept.wait_for(state="visible", timeout=2000)
        await modal_accept.click()
        print("[auto-accept] Clicked modal Accept confirmation.")
    except Exception:
        # Modal didn’t appear (normal case)
        pass

    # Let the UI settle after accepting
    try:
        await page.wait_for_load_state("networkidle", timeout=10000)
    except Exception:
        pass

    return True

async def main() -> None:
    username = os.getenv("FRONTLINE_USERNAME")
    password = os.getenv("FRONTLINE_PASSWORD")
    if not username or not password:
        print("Missing credentials")
        print()
        print(
            "If code was cloned to a new instance/account, then it's very likely "
            "that the issue is that a .env file is still needed with the three "
            "variables required from the code (see the .env file from the account "
            "cloned for a template, but put in the new values)."
        )
        sys.exit(1)

    # Load filters
    include_any_words = get_include_any_words()
    exclude_any_words = get_exclude_any_words()
    include_count_words, include_min_matches = get_include_count_words()
    exclude_count_words, exclude_min_matches = get_exclude_count_words()

    print("[filter] include_any_words:", include_any_words or "(none)")
    print("[filter] exclude_any_words:", exclude_any_words or "(none)")
    print(
        "[filter] include_count_words:",
        include_count_words or "(none)",
        "min_matches:",
        include_min_matches,
    )
    print(
        "[filter] exclude_count_words:",
        exclude_count_words or "(none)",
        "min_matches:",
        exclude_min_matches,
    )

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto(JOBS_URL)
        await page.wait_for_load_state("domcontentloaded")

        if "login.frontlineeducation.com" in page.url:
            print("[auth] Not logged in at start, attempting login...")
            await page.goto(LOGIN_URL)
            ok = await ensure_logged_in(page, username, password)
            if ok:
                print("[auth] Login appears successful, returning to jobs page.")
                await page.goto(JOBS_URL)

        await page.wait_for_load_state("networkidle")

        baseline = await get_available_jobs_snapshot(page)
        print("[*] Monitoring started.")
        print(f"[available_jobs baseline]:\n{baseline[:500]}")
        notify("Frontline watcher started")

        while True:
            try:
                await page.reload(wait_until="networkidle")
            except PWTimeout:
                print("[!] reload timeout")

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

            current = await get_available_jobs_snapshot(page)
            print(f"[available_jobs now]:\n{current[:500]}")

            if current != baseline:
                change_type = summarize_change(baseline, current)
                print("\n=== CHANGE DETECTED ===")
                print(f"[change_type] {change_type}")
                print(diff_for_logs(baseline, current))

                if change_type == "NEW FRONTLINE JOB":
                    filtered_snapshot = apply_job_filters_to_snapshot(
                        snapshot=current,
                        include_any_words=include_any_words,
                        exclude_any_words=exclude_any_words,
                        include_count_words=include_count_words,
                        include_min_matches=include_min_matches,
                        exclude_count_words=exclude_count_words,
                        exclude_min_matches=exclude_min_matches,
                    )

                    if filtered_snapshot is None:
                        print(
                            "[filter] Job change did not pass filters; "
                            "skipping notification."
                        )
                    else:
                        message = f"🆕 NEW FRONTLINE JOB:\n{filtered_snapshot}"
                        notify(message)
                        print(f"Sent notification: {message}")

                        accepted = await try_accept_first_visible_job(page)
                        if accepted:
                            notify("✅ Auto-accept attempted (clicked Accept).")
                            print("[auto-accept] Accept flow attempted.")
                        else:
                            notify("⚠️ Auto-accept failed (no visible Accept button found).")
                            print("[auto-accept] Accept flow did not run.")


                elif change_type == "PREVIOUS JOB HAS EXPIRED":
                    message = (
                        "⏳ PREVIOUS JOB HAS EXPIRED:\n"
                        "I'm sorry. There are no available assignments at the moment."
                    )
                    notify(message)
                    print(f"Sent notification: {message}")

                else:
                    message = f"🔄 UPDATE:\n{current}"
                    notify(message)
                    print(f"Sent notification: {message}")

                baseline = current

            delay = get_random_delay()
            print(f"(sleeping {delay:.2f}s)")
            await asyncio.sleep(delay)


if __name__ == "__main__":
    asyncio.run(main())
