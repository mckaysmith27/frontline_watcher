# 📱 Adding Capabilities in Xcode - Detailed Guide

## Step-by-Step: Adding Push Notifications & Background Modes

### Step 1: Open Signing & Capabilities Tab

1. **In Xcode**, make sure you have the **Runner.xcworkspace** open
2. **Click on "Runner"** in the left sidebar (the blue project icon at the very top)
3. **In the main area**, you'll see tabs at the top:
   - General
   - Signing & Capabilities ← **Click this tab**
   - Resource Tags
   - Info
   - Build Settings
   - etc.

### Step 2: Add Push Notifications Capability

1. **In the "Signing & Capabilities" tab**, look for a section that says:
   - "Capabilities" (if you already have some)
   - Or an empty area with a "+ Capability" button

2. **Click the "+ Capability" button** (usually in the top-right of the Capabilities section)

3. **A search/dropdown menu will appear** with a list of capabilities

4. **Type "Push"** in the search box, or scroll to find:
   - **"Push Notifications"** ← Select this one
   - It might also be listed as just "Push Notifications" without any icon initially

5. **After selecting**, you should see:
   - A new section appears showing "Push Notifications"
   - It should have a checkmark or show as enabled

### Step 3: Add Background Modes Capability

1. **Still in "Signing & Capabilities" tab**

2. **Click "+ Capability" again** (same button as before)

3. **In the search/dropdown**, type "Background" or scroll to find:
   - **"Background Modes"** ← Select this one
   - It might be listed as "Background Modes" or "Background"

4. **After selecting**, you'll see a new "Background Modes" section appear

5. **Expand the "Background Modes" section** (click the arrow/disclosure triangle)

6. **Check the box next to:**
   - ✅ **"Remote notifications"**
   - This enables push notifications to work when the app is in the background

## 🎯 Visual Guide - What You Should See

### Before Adding Capabilities:
```
Signing & Capabilities Tab:
┌─────────────────────────────────────┐
│ Signing & Capabilities              │
├─────────────────────────────────────┤
│ Team: [Your Apple ID]               │
│ Bundle Identifier: com.sub67.app    │
│                                     │
│ Capabilities:                       │
│   [+ Capability] ← Click here       │
└─────────────────────────────────────┘
```

### After Adding Push Notifications:
```
Signing & Capabilities Tab:
┌─────────────────────────────────────┐
│ Signing & Capabilities              │
├─────────────────────────────────────┤
│ Team: [Your Apple ID]               │
│                                     │
│ Capabilities:                       │
│   ✅ Push Notifications             │
│   [+ Capability] ← Click again      │
└─────────────────────────────────────┘
```

### After Adding Background Modes:
```
Signing & Capabilities Tab:
┌─────────────────────────────────────┐
│ Signing & Capabilities              │
├─────────────────────────────────────┤
│ Team: [Your Apple ID]               │
│                                     │
│ Capabilities:                       │
│   ✅ Push Notifications             │
│   ✅ Background Modes                │
│      ▼ Remote notifications ✅       │
│   [+ Capability]                    │
└─────────────────────────────────────┘
```

## 🔍 Alternative: If You Can't Find the Capabilities

### Option 1: Check if Already Added
Sometimes capabilities are added automatically. Check if you see:
- Any section that says "Push" or "Notifications"
- Any section that says "Background" or "Background Modes"

### Option 2: Search in the Capability List
When you click "+ Capability", try searching for:
- "Push" (not "Push Notifications")
- "Background" (not "Background Modes")
- "Remote notifications" (might be listed separately)

### Option 3: Check Project Settings
1. Go to **"Build Settings"** tab
2. Search for "capabilities" in the search box
3. Look for any push notification or background mode settings

## 🆘 Troubleshooting

### "I don't see a '+ Capability' button"
- Make sure you're in the **"Signing & Capabilities"** tab
- Make sure you selected the **"Runner" target** (not the project)
- Try clicking on "Runner" in the left sidebar, then the "Signing & Capabilities" tab

### "The capabilities don't appear in the list"
- Make sure you have a valid Apple Developer account selected as your Team
- Try signing out and back in to your Apple ID in Xcode
- Go to Xcode > Settings > Accounts, and verify your Apple ID

### "I see the capability but can't enable it"
- Make sure "Automatically manage signing" is checked
- Make sure you've selected a valid Team (your Apple ID)
- You might need a paid Apple Developer account for some capabilities (but Push Notifications should work with a free account)

## ✅ Verification Checklist

After adding both capabilities, you should see:

- [ ] "Push Notifications" appears in the Capabilities list
- [ ] "Background Modes" appears in the Capabilities list
- [ ] "Remote notifications" is checked under Background Modes
- [ ] No red error messages in the Signing & Capabilities tab
- [ ] Your Team (Apple ID) is selected

## 📝 Quick Reference

**Location:** Runner project > Runner target > Signing & Capabilities tab  
**Button:** "+ Capability" (top of Capabilities section)  
**Capabilities to add:**
1. Push Notifications
2. Background Modes (then check "Remote notifications")

## 🎉 Next Steps

After adding both capabilities:
1. Save the Xcode project (Cmd+S)
2. Close Xcode
3. Run: `./check-setup.sh` to verify everything
4. Test: `./launch-ios.sh`

