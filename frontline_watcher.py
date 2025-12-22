print("🚨 CODE VERSION V3-20 — Auto-accept + Filters + Datetime/Timestamps 🚨")

import asyncio
import difflib
import os
import sys
import random
from typing import Optional
from urllib import request
from datetime import datetime, timezone, timedelta

from playwright.async_api import async_playwright, TimeoutError as PWTimeout

#init
SELFTEST_SENTINEL = "/tmp/frontline_selftest_done"
SELFTEST_ENABLED = os.getenv("SELFTEST_ON_START", "1") == "1"
DRY_RUN_ACCEPT = os.getenv("DRY_RUN_ACCEPT", "1") == "1"   # default safe


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
# MIN_DELAY = 16
# MAX_DELAY = 31
MIN_DELAY = 7
MAX_DELAY = 16

def get_random_delay() -> float:
    """Return a random delay between MIN_DELAY and MAX_DELAY seconds."""
    return random.uniform(MIN_DELAY, MAX_DELAY)

def notify(message: str) -> None:
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
    except Exception as e:
        log(f"[notify error] {e}")

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
        conf_num = await safe_text("span.confNum")  # often equals job_id, but grab anyway
        item_date = await safe_text("span.itemDate")
        start_time = await safe_text("span.startTime")
        end_time = await safe_text("span.endTime")
        duration = await safe_text("span.durationName")
        location = await safe_text("div.locationName")

        # fallback duration if durationName isn't what the UI shows (sometimes "Full Day")
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

async def run_startup_selftest(page) -> None:
    """
    Runs once per container start.
    If there are no real jobs, injects a mock job DOM and tests selector/click logic.
    """

    if not DRY_RUN_ACCEPT:
        log("[selftest] DRY_RUN_ACCEPT=0 (LIVE). Skipping selftest to avoid real accept.")
        return

    try:
        jobs = page.locator("#availableJobs tbody.job")
        count = await jobs.count()
        log(f"[selftest] tbody.job count={count}")

        # If a real job exists, test against the first real job id
        if count > 0:
            first = jobs.first
            conf_id = (await first.get_attribute("id")) or ""
            log(f"[selftest] Real job found. Using id={conf_id!r} for selector test.")
            job_block = (
                f"CONFIRMATION #{conf_id}\n"
                "TEACHER: Selftest, Real\n"
                "TITLE: Selftest\n"
                "DATE: Thu, 12/18/2025\n"
                "TIME: 8:00 AM - 2:45 PM\n"
                "DURATION: Full Day\n"
                "LOCATION: Selftest School"
            )
            ok = await try_accept_job_block(page, job_block)
            log(f"[selftest] try_accept_job_block returned {ok}")
            return

        # Otherwise inject a mock listing DOM
        log("[selftest] No jobs visible; injecting mock #availableJobs DOM for testing.")

        mock_conf = "999999999"
        mock_html = f"""
        <div id="availableJobs">
          <table class="jobList fullwidth">
            <tbody class="job" id="{mock_conf}" style="display: table-row-group;">
              <tr class="summary">
                <td colspan="5">
                  <div>
                    <div class="grid_6 alpha">
                      <span class="name">Selftest, Teacher</span>
                      <span class="title">Teacher-English</span>
                    </div>
                    <div class="grid_6 omega right floatRight">
                      <span class="conf">Confirmation #<span class="confNum">{mock_conf}</span></span>
                      <a class="rejectButton negative button" role="presentation"><span>Reject</span></a>
                      <a class="acceptButton positiveDefault button"
                         role="presentation"
                         data-selftest="accept">
                        <span>Accept</span>
                      </a>
                      <a class="showDetailsButton expand button" role="presentation"><span>See Details</span></a>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="detail">
                <td class="date"><span class="itemDate">Thu, 12/18/2025</span></td>
                <td class="times"><span class="startTime">8:00 AM</span> - <span class="endTime">2:45 PM</span></td>
                <td class="duration"><span class="durationName">Full Day</span></td>
                <td class="location"><div class="locationName">Mock Middle School</div></td>
                <td class="more"></td>
              </tr>
            </tbody>
          </table>
        </div>

        """

        # Inject into the existing page WITHOUT navigating away
        await page.evaluate(
            """(html) => {
                const host = document.querySelector("#availableJobs") || document.body;
                host.insertAdjacentHTML("beforeend", html);
                window.__accepted = false;
            }""",
            mock_html,
        )

        # Now run the normal accept code against the mock job
        job_block = (
            f"CONFIRMATION #{mock_conf}\n"
            "TEACHER: Selftest, Teacher\n"
            "TITLE: Teacher-English\n"
            "DATE: Thu, 12/18/2025\n"
            "TIME: 8:00 AM - 2:45 PM\n"
            "DURATION: Full Day\n"
            "LOCATION: Mock Middle School"
        )

        ok = await try_accept_job_block(page, job_block)
        log(f"[selftest] try_accept_job_block returned {ok}")

        # In DRY RUN we do NOT click; success means we located the Accept button safely.
        if ok:
            log("[selftest] ✅ DRY RUN selftest passed: Accept button located (no click).")
        else:
            log("[selftest] ❌ DRY RUN selftest failed: Accept button not located.")

        # --- CLEAN UP MOCK JOB SO IT DOES NOT POLLUTE BASELINE ---
        try:
            await page.evaluate("""() => {
                const fake = document.querySelector(
                    '#availableJobs tbody.job[id="999999999"]'
                );
                if (fake) {
                    fake.remove();
                }
            }""")
            log("[selftest] mock job removed from DOM")
        except Exception as e:
            log(f"[selftest] failed to remove mock job: {e}")

    except Exception as e:
        log(f"[selftest] Exception: {e}")

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

def extract_unique_words_no_regex(text: str) -> list[str]:
    """
    Extract unique lowercase words using only basic string operations.
    Strips common punctuation and splits on whitespace.
    """
    # Characters we consider separators / junk
    punctuation = ",.;:!?()[]{}<>\"'\\/\n\t"

    cleaned = text.lower()
    for ch in punctuation:
        cleaned = cleaned.replace(ch, " ")

    words = [w for w in cleaned.split(" ") if w]
    return sorted(set(words))

def pick_job_key_lines(job_block: str, max_lines: int = 3) -> list[str]:
    lines = [ln.strip() for ln in job_block.splitlines() if ln.strip()]

    def score(line: str) -> int:
        s = 0
        if any(w in line for w in WEEKDAY_WORDS):
            s += 5
        if (" AM" in line) or (" PM" in line):
            s += 4
        if any(tok in line for tok in ["Elementary", "Middle", "High School", "Teacher", "Grade"]):
            s += 3
        if len(line) >= 12:
            s += 1
        return s

    scored = sorted(lines, key=score, reverse=True)
    picked: list[str] = []
    for ln in scored:
        if ln not in picked:
            picked.append(ln)
        if len(picked) >= max_lines:
            break

    if not picked and lines:
        picked = lines[:1]

    return picked

async def _handle_dom_confirm_if_present(page) -> bool:
    """
    Some confirmations are not JS dialogs; they're DOM modals.
    We'll look for a visible modal-ish container with Accept/Cancel buttons.
    """
    modal = page.locator(
        '[role="dialog"], .ui-dialog, .modal, .modal-dialog, .dialog'
    ).filter(has_text="Accept").first

    try:
        if await modal.count() == 0:
            return False
        if not await modal.is_visible():
            return False

        log("[auto-accept] DOM confirm modal detected; attempting confirm Accept...")

        # Prefer explicit Accept button inside modal
        accept_btn = modal.locator(
            'button:has-text("Accept"), a:has-text("Accept"), [role="button"]:has-text("Accept")'
        ).first

        if await accept_btn.count() > 0 and await accept_btn.is_visible():
            try:
                await accept_btn.click(timeout=4000)
            except Exception:
                await accept_btn.click(timeout=4000, force=True)

            try:
                await page.wait_for_load_state("networkidle", timeout=8000)
            except Exception:
                pass

            log("[auto-accept] ✅ Confirmed Accept in DOM modal.")
            return True

    except Exception as e:
        log(f"[auto-accept] DOM confirm handler error: {e}")

    return False


def extract_confirmation_id(job_block: str) -> str:
    for ln in job_block.splitlines():
        ln = ln.strip()
        if ln.upper().startswith("CONFIRMATION #"):
            return ln.split("#", 1)[1].strip()
    return ""


async def try_accept_job_block(page, job_block: str) -> bool:
    conf_id = extract_confirmation_id(job_block)
    log(f"[auto-accept] job_block conf_id='{conf_id}'")

    jobs = page.locator("#availableJobs tbody.job")
    try:
        count = await jobs.count()
    except Exception:
        count = 0
    log(f"[auto-accept] page currently has {count} tbody.job containers; url={page.url}")

    if not conf_id:
        log("[auto-accept] ❌ No confirmation id in job_block; cannot do reliable accept.")
        return False

    # IMPORTANT: numeric id => use attribute selector, NOT #id
    target = page.locator(f'#availableJobs tbody.job[id="{conf_id}"]')

    try:
        tcount = await target.count()

        log(
            "[auto-accept] 🔍 JOB CONTAINER MATCH\n"
            f"  ├─ confirmation_id             = {conf_id}\n"
            f"  ├─ selector                    = #availableJobs tbody.job[id=\"{conf_id}\"]\n"
            f"  ├─ total_tbody.job_on_page      = {count}\n"
            f"  ├─ matching_tbody.job_for_id    = {tcount}\n"
            f"  └─ page_url                    = {page.url}"
        )

        if tcount == 0:
            # dump the ids we *do* see, for debugging
            ids_seen = []
            for i in range(min(count, 10)):
                try:
                    jid = await jobs.nth(i).get_attribute("id")
                except Exception:
                    jid = None
                if jid:
                    ids_seen.append(jid)

            log(
                "[auto-accept] ❌ NO MATCHING JOB CONTAINER\n"
                f"  ├─ requested_confirmation_id   = {conf_id}\n"
                f"  ├─ ids_seen_first10            = {ids_seen}\n"
                "  └─ next_step                  = verify confirmation id in snapshot matches tbody.job id"
            )
            return False

        accept = target.locator("a.acceptButton").first
        acount = await accept.count()

        try:
            accept_text = (await accept.inner_text()).strip() if acount > 0 else ""
        except Exception:
            accept_text = ""

        log(
            "[auto-accept] 🧩 ACCEPT BUTTON DISCOVERY\n"
            f"  ├─ accept_locator              = a.acceptButton (scoped to matched tbody.job)\n"
            f"  ├─ accept_count                = {acount}\n"
            f"  └─ accept_inner_text           = {accept_text!r}"
        )

        if acount == 0:
            # log a snippet of the text in the container
            try:
                txt = await target.inner_text()
                snippet = txt[:400]
            except Exception:
                snippet = "(could not read inner_text)"

            log(
                "[auto-accept] ❌ ACCEPT BUTTON NOT FOUND INSIDE CONTAINER\n"
                f"  ├─ confirmation_id             = {conf_id}\n"
                f"  └─ container_text_snippet_400  = {snippet!r}"
            )
            return False

        # visibility/enabled info
        try:
            vis = await accept.is_visible()
        except Exception:
            vis = None
        try:
            enabled = await accept.is_enabled()
        except Exception:
            enabled = None

        log(
            "[auto-accept] ✅ ACCEPT BUTTON READY CHECK\n"
            f"  ├─ visible                     = {vis}\n"
            f"  ├─ enabled                     = {enabled}\n"
            f"  └─ dry_run_mode                = {DRY_RUN_ACCEPT}"
        )

        await accept.scroll_into_view_if_needed()

        log(
            "[auto-accept] 🎯 ACTION DECISION\n"
            f"  ├─ confirmation_id             = {conf_id}\n"
            f"  └─ next_action                 = "
            + ("DRY RUN (no click)" if DRY_RUN_ACCEPT else "LIVE CLICK")
        )

        if DRY_RUN_ACCEPT:
            log(
                "[auto-accept] 🟡 DRY RUN COMPLETE\n"
                f"  ├─ confirmed_accept_selector   = True\n"
                f"  ├─ confirmed_container_match   = True\n"
                f"  └─ would_click_confirmation    = {conf_id} (but did not click)"
            )
            return True


        # LIVE mode click
        try:
            await accept.click(timeout=6000)

        except Exception as e1:
            log(f"[auto-accept] normal click failed: {e1} -> trying force click")
            await accept.click(timeout=6000, force=True)

        # settle
        try:
            await page.wait_for_load_state("networkidle", timeout=8000)
        except Exception:
            pass

        # handle DOM confirm if present
        confirmed = await _handle_dom_confirm_if_present(page)
        if confirmed:
            return True

        log(f"[auto-accept] ✅ Clicked Accept for confirmation #{conf_id}")
        return True

    except Exception as e:
        log(f"[auto-accept] ❌ Exception during accept for #{conf_id}: {e}")
        return False


async def _try_accept_with_details_fallback(page, container) -> bool:
    """
    Try to click Accept within the matched container.
    If not found, try opening Details then click Accept.
    """
    # 1) Try Accept directly inside the container
    accept = container.locator(
        'button:has-text("Accept"), a:has-text("Accept"), [role="button"]:has-text("Accept")'
    ).first

    try:
        if await accept.count() > 0:
            await accept.scroll_into_view_if_needed()
            await accept.click(timeout=3000)
            try:
                await page.wait_for_load_state("networkidle", timeout=8000)
            except Exception:
                pass
            return True
    except Exception:
        pass

    # 2) Try clicking Details / View Details first
    details = container.locator(
        'button:has-text("Details"), a:has-text("Details"), '
        'button:has-text("View Details"), a:has-text("View Details"), '
        'button:has-text("More"), a:has-text("More")'
    ).first

    try:
        if await details.count() > 0:
            await details.scroll_into_view_if_needed()
            await details.click(timeout=3000)
            try:
                await page.wait_for_load_state("domcontentloaded", timeout=8000)
            except Exception:
                pass
    except Exception:
        # If Details click fails, still try global Accept below
        pass

    # 3) Try global Accept (some sites show Accept in a modal/panel outside container)
    global_accept = page.locator(
        'button:has-text("Accept"), a:has-text("Accept"), [role="button"]:has-text("Accept")'
    ).first

    try:
        if await global_accept.count() > 0:
            await global_accept.scroll_into_view_if_needed()
            await global_accept.click(timeout=3000)
            try:
                await page.wait_for_load_state("networkidle", timeout=8000)
            except Exception:
                pass
            return True
    except Exception:
        pass

    return False

async def try_accept_from_filtered_snapshot(page, filtered_snapshot: str) -> bool:
    """
    filtered_snapshot may contain:
      - "NO_AVAILABLE_JOBS"
      - one job block
      - multiple job blocks separated by blank lines
    Try to accept the first acceptable job block.
    """
    if not filtered_snapshot or filtered_snapshot.strip() == "NO_AVAILABLE_JOBS":
        return False

    blocks = [b.strip() for b in filtered_snapshot.split("\n\n") if b.strip()]
    for idx, block in enumerate(blocks):
        log(f"[auto-accept] trying block index {idx}")
        ok = await try_accept_job_block(page, block)
        if ok:
            log(f"[auto-accept] Accepted block index {idx}.")
            return True

    return False


async def run_startup_selftest_once(page) -> None:
    if not SELFTEST_ENABLED:
        log("[selftest] disabled (SELFTEST_ON_START!=1)")
        return

    if os.path.exists(SELFTEST_SENTINEL):
        log("[selftest] already ran for this container; skipping")
        return

    # Mark immediately so we don't loop if something goes wrong mid-test
    try:
        with open(SELFTEST_SENTINEL, "w") as f:
            f.write(datetime.utcnow().isoformat() + "Z")
    except Exception as e:
        log(f"[selftest] could not write sentinel: {e}")

    # Run the real injector-based selftest (works even when there are no real jobs)
    await run_startup_selftest(page)

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

    relogin_failures = 0
    MAX_RELOGIN_FAILURES = 5

    log(f"[auto-accept] DRY_RUN_ACCEPT={DRY_RUN_ACCEPT}")

    async with async_playwright() as p:

        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()
        page.on("dialog", lambda d: asyncio.create_task(d.accept()))

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

        await run_startup_selftest_once(page)

        baseline = await get_available_jobs_snapshot(page)
        log("[*] Monitoring started.")
        log(f"[available_jobs baseline]:\n{baseline[:500]}")


        # notify("Frontline watcher started")
        if os.getenv("SENT_STARTUP_NOTIFY") != "1":
            notify("Frontline watcher started")
            os.environ["SENT_STARTUP_NOTIFY"] = "1"

        while True:
            try:
                await page.reload(wait_until="networkidle")
            except PWTimeout:
                log("[!] reload timeout")

            if "login.frontlineeducation.com" in page.url:
                relogin_failures += 1
                print(f"[auth] Session expired. Re-auth... (failures={relogin_failures}/{MAX_RELOGIN_FAILURES})")

                # Go to login page with a longer timeout and lighter wait condition
                try:
                    await page.goto(LOGIN_URL, wait_until="domcontentloaded", timeout=60000)
                except Exception as e:
                    print(f"[auth] goto(LOGIN_URL) failed: {e}")
                    if relogin_failures >= MAX_RELOGIN_FAILURES:
                        notify("🔥 Frontline watcher: login page keeps timing out. Stopping (SSO/network issue).")
                        raise
                    await asyncio.sleep(5)
                    continue

                ok = await ensure_logged_in(page, username, password)

                if ok:
                    print("[auth] Login attempt looks OK; going back to jobs page.")
                    try:
                        await page.goto(JOBS_URL, wait_until="networkidle", timeout=60000)
                        relogin_failures = 0  # reset on success
                    except Exception as e:
                        print(f"[auth] goto(JOBS_URL) failed after login: {e}")
                        # don't crash immediately; try again next loop
                        await asyncio.sleep(5)
                        continue
                else:
                    print("[auth] Re-login failed / still gated by SSO.")
                    if relogin_failures >= MAX_RELOGIN_FAILURES:
                        notify("🔥 Frontline watcher: blocked by SSO/captcha; cannot auto-login. Stopping.")
                        raise
                    await asyncio.sleep(10)
                    continue


            current = await get_available_jobs_snapshot(page)
            log(f"[available_jobs now]:\n{current[:500]}")


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
                        all_words: set[str] = set()
                        for block in filtered_snapshot.split("\n\n"):
                            for w in extract_unique_words_no_regex(block):
                                all_words.add(w)

                        word_list = ", ".join(sorted(all_words))

                        message = (
                            "🆕 NEW FRONTLINE JOB\n\n"
                            f"{filtered_snapshot}\n\n"
                            "🔎 WORDS FOUND:\n"
                            f"{word_list}"
                        )

                        notify(message)
                        log(f"Sent notification: {message}")


                        accepted = await try_accept_from_filtered_snapshot(page, filtered_snapshot)
                        if accepted:
                            notify("✅ Auto-accept succeeded (matched job block and clicked Accept).")
                            log("[auto-accept] Success.")
                        else:
                            notify("⚠️ Auto-accept failed (could not match job block to a container with Accept).")
                            log("[auto-accept] Failed to match/click Accept for the filtered job.")

                elif change_type == "PREVIOUS JOB HAS EXPIRED":
                    message = (
                        "⏳ PREVIOUS JOB HAS EXPIRED:\n"
                        "I'm sorry. There are no available assignments at the moment."
                    )
                    notify(message)
                    log(f"Sent notification: {message}")

                else:
                    message = f"🔄 UPDATE:\n{current}"
                    notify(message)
                    log(f"Sent notification: {message}")

                baseline = current

            delay = get_random_delay()
            log(f"(sleeping {delay:.2f}s)")

            await asyncio.sleep(delay)


if __name__ == "__main__":
    asyncio.run(main())
