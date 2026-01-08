# Filter Logic Explained

## How Filtering Works

### Green Tags (Included) ✅
- **Meaning**: Jobs that match **ANY ONE** of your green tags will be shown
- **Logic**: **OR** logic (at least one match required)
- **Example**: 
  - If you mark "elementary" and "middle school" as green
  - You'll get notifications for jobs that contain **either** "elementary" **OR** "middle school" (or both)
  - You do **NOT** need both to be present

### Red Tags (Excluded) ❌
- **Meaning**: Jobs that contain **ANY** red tag are automatically ruled out
- **Logic**: **Exclusion** (if any red tag matches, job is blocked)
- **Example**:
  - If you mark "kindergarten" as red
  - Any job containing "kindergarten" will be automatically excluded
  - Even if it matches your green tags, it won't be shown

### Gray Tags (Neutral) ⚪
- **Meaning**: These tags are ignored - they don't affect filtering
- **Logic**: Neither included nor excluded

## How It Works in Practice

### Example 1: Simple Include
- **Green**: "elementary", "middle school"
- **Red**: None
- **Result**: Get notifications for jobs containing "elementary" OR "middle school"

### Example 2: Include + Exclude
- **Green**: "elementary", "middle school", "high school"
- **Red**: "kindergarten"
- **Result**: 
  - Get notifications for "elementary", "middle school", or "high school" jobs
  - BUT exclude any job that mentions "kindergarten" (even if it also mentions "elementary")

### Example 3: No Filters
- **Green**: None
- **Red**: None
- **Result**: Get notifications for **ALL** jobs (no filtering)

## Backend Matching Logic

The Cloud Function (`functions/index.js`) matches jobs like this:

1. **Check Included Words** (green tags):
   - If you have any green tags, the job must match **at least one**
   - If no green tags, skip this check

2. **Check Excluded Words** (red tags):
   - If the job contains **any** red tag, it's immediately excluded
   - Even if it matches green tags, red tags take priority

3. **Result**:
   - Job passes if: (matches at least one green OR no greens set) AND (doesn't match any red)

## Summary

- **Green = OR logic**: At least one must be present
- **Red = Exclusion**: Any red tag automatically rules out the job
- **Gray = Ignored**: Doesn't affect filtering

