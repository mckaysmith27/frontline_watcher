#!/bin/bash

# Script to create authenticated browser context for EC2 scrapers
# This allows bypassing SSO by using pre-authenticated cookies
# Usage: ./create-auth-context.sh [controller_number]

set -e

CONTROLLER_NUM="${1:-1}"
EC2_HOST="sub67-watcher"
STORAGE_FILE="storage_state_controller_${CONTROLLER_NUM}.json"

echo "🔐 Creating Authenticated Browser Context for Controller ${CONTROLLER_NUM}"
echo "======================================================================"
echo ""
echo "This script will:"
echo "  1. Run a visible browser on EC2"
echo "  2. You'll manually complete SSO login"
echo "  3. Save the authenticated session to ${STORAGE_FILE}"
echo ""
echo "⚠️  IMPORTANT: You'll need to SSH into EC2 and complete the login manually"
echo ""
read -p "Press Enter to continue..."

# Create Python script on EC2
ssh ${EC2_HOST} << EOF
cat > /tmp/create_auth_context.py << 'PYTHON_SCRIPT'
import asyncio
import os
import sys
from playwright.async_api import async_playwright

CONTROLLER_ID = os.getenv("CONTROLLER_ID", "controller_${CONTROLLER_NUM}")
STORAGE_PATH = f"/opt/frontline-watcher/storage_state_{CONTROLLER_ID}.json"

LOGIN_URL = (
    "https://login.frontlineeducation.com/login"
    "?signin=a6740188d37bd24dc70d4748ad55028e"
    "&productId=ABSMGMT&clientId=ABSMGMT#/login"
)

JOBS_URL = "https://absencesub.frontlineeducation.com/Substitute/Home"

async def main():
    print(f"🔐 Creating authenticated context for {CONTROLLER_ID}")
    print(f"📁 Will save to: {STORAGE_PATH}")
    print("")
    print("⚠️  A browser window will open. Please:")
    print("   1. Complete SSO login manually")
    print("   2. Navigate to the jobs page")
    print("   3. Wait for the script to save the context")
    print("")
    input("Press Enter when ready...")
    
    async with async_playwright() as p:
        # Launch visible browser (NOT headless)
        browser = await p.chromium.launch(headless=False)
        context = await browser.new_context()
        page = await context.new_page()
        
        print("🌐 Opening login page...")
        await page.goto(LOGIN_URL)
        
        print("")
        print("=" * 60)
        print("⏸️  MANUAL STEP REQUIRED")
        print("=" * 60)
        print("In the browser window:")
        print("  1. Complete SSO login")
        print("  2. Navigate to jobs page")
        print("  3. Verify you can see available jobs")
        print("")
        input("Press Enter AFTER you've successfully logged in...")
        
        # Verify we're logged in
        await page.goto(JOBS_URL)
        await page.wait_for_load_state("networkidle", timeout=30000)
        
        if "login.frontlineeducation.com" in page.url:
            print("❌ ERROR: Still on login page!")
            print("   Please complete authentication and try again.")
            await browser.close()
            sys.exit(1)
        
        # Save the storage state
        print("💾 Saving authenticated session...")
        os.makedirs(os.path.dirname(STORAGE_PATH), exist_ok=True)
        await context.storage_state(path=STORAGE_PATH)
        
        print(f"✅ Saved authenticated context to {STORAGE_PATH}")
        print("")
        print("🔒 Setting permissions...")
        os.chmod(STORAGE_PATH, 0o600)
        
        await browser.close()
        print("✅ Done!")

if __name__ == "__main__":
    asyncio.run(main())
PYTHON_SCRIPT
EOF

echo ""
echo "📋 Next steps:"
echo "  1. SSH into EC2: ssh ${EC2_HOST}"
echo "  2. Set environment variables:"
echo "     export CONTROLLER_ID=controller_${CONTROLLER_NUM}"
echo "     export FRONTLINE_USERNAME=your_username"
echo "     export FRONTLINE_PASSWORD=your_password"
echo "  3. Run: python3 /tmp/create_auth_context.py"
echo "  4. Complete SSO login in the browser window"
echo "  5. The context will be saved automatically"
echo ""
echo "After creating the context, restart the service:"
echo "  ssh ${EC2_HOST} 'sudo systemctl restart frontline-watcher-controller_${CONTROLLER_NUM}'"
