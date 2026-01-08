#!/usr/bin/env python3
"""
Helper script to manually authenticate and save browser context.
Run this locally (not in Cloud Run) to create an authenticated session.

Usage:
    python save-auth-context.py
"""

import asyncio
import json
import os
from playwright.async_api import async_playwright

STORAGE_STATE_PATH = os.getenv("STORAGE_STATE_PATH", "/tmp/frontline_storage_state.json")
LOGIN_URL = (
    "https://login.frontlineeducation.com/login"
    "?signin=a6740188d37bd24dc70d4748ad55028e"
    "&productId=ABSMGMT&clientId=ABSMGMT#/login"
)
JOBS_URL = "https://absencesub.frontlineeducation.com/Substitute/Home"

async def main():
    print("🔐 Frontline Authentication Helper")
    print("=" * 50)
    print()
    print("This script will:")
    print("  1. Open a browser window (NOT headless)")
    print("  2. Navigate to Frontline login")
    print("  3. YOU will manually complete SSO authentication")
    print("  4. Save the authenticated session (cookies) to a file")
    print()
    print(f"Storage state will be saved to: {STORAGE_STATE_PATH}")
    print()
    input("Press Enter to continue...")

    async with async_playwright() as p:
        # Launch browser in visible mode (NOT headless)
        print("\n🌐 Opening browser...")
        browser = await p.chromium.launch(headless=False)
        context = await browser.new_context()
        page = await context.new_page()

        print(f"\n📋 Navigating to login page...")
        print("   URL: https://login.frontlineeducation.com/...")
        await page.goto(LOGIN_URL)
        
        print("\n" + "=" * 50)
        print("⏸️  MANUAL STEP REQUIRED")
        print("=" * 50)
        print("\nIn the browser window that opened:")
        print("  1. Complete the SSO login process")
        print("  2. Navigate through any 2FA/MFA steps")
        print("  3. Get to the jobs page (you should see available jobs)")
        print("  4. Once you're successfully logged in, come back here")
        print()
        input("Press Enter AFTER you've successfully logged in...")

        # Verify we're logged in
        current_url = page.url
        if "login.frontlineeducation.com" in current_url:
            print("\n❌ ERROR: Still on login page!")
            print("   Please complete authentication and try again.")
            await browser.close()
            return

        # Navigate to jobs page to verify
        print("\n✅ Appears logged in! Verifying...")
        await page.goto(JOBS_URL)
        await page.wait_for_load_state("load", timeout=30000)

        if "login.frontlineeducation.com" in page.url:
            print("\n❌ ERROR: Redirected back to login page!")
            print("   Authentication may have failed. Please try again.")
            await browser.close()
            return

        # Save the storage state
        print("\n💾 Saving authenticated session...")
        storage_state = await context.storage_state()
        
        # Ensure directory exists
        os.makedirs(os.path.dirname(STORAGE_STATE_PATH) if os.path.dirname(STORAGE_STATE_PATH) else '.', exist_ok=True)
        
        with open(STORAGE_STATE_PATH, 'w') as f:
            json.dump(storage_state, f, indent=2)
        
        print(f"✅ Saved to: {STORAGE_STATE_PATH}")
        print()
        print("=" * 50)
        print("🎉 Success!")
        print("=" * 50)
        print()
        print("Next steps:")
        print("  1. Upload this file to Google Secret Manager:")
        print(f"     gcloud secrets create frontline-browser-context \\")
        print(f"       --data-file={STORAGE_STATE_PATH} \\")
        print(f"       --project sub67-d4648")
        print()
        print("  2. Update Cloud Run Jobs to use this context")
        print("     (See SSO_AUTH_GUIDE.md for details)")
        print()

        await browser.close()

if __name__ == "__main__":
    asyncio.run(main())

