# Love2D Filesystem Diagnostic Test Instructions

## **Test Overview**
The BalatroMCP mod has been updated with comprehensive filesystem diagnostics to identify why file operations are failing. This will help us understand Love2D's actual filesystem restrictions in the Balatro/Steammodded environment.

## **What the Diagnostic Will Test**

### **1. Love2D Availability & Version**
- Checks if `love.filesystem` is available
- Reports Love2D version information
- Tests basic Love2D functionality

### **2. Directory Information**
- Working Directory: `love.filesystem.getWorkingDirectory()`
- Save Directory: `love.filesystem.getSaveDirectory()`
- Source Directory: `love.filesystem.getSourceBaseDirectory()`
- Real Directory: `love.filesystem.getRealDirectory(".")`

### **3. Current Directory Contents**
- Lists all files/directories visible to Love2D
- Shows what the mod can actually "see" in its environment
- Identifies available paths and structures

### **4. Write Permission Tests**
Tests file creation in multiple locations:
- `test_write.txt` (current directory)
- `shared/test_write.txt` (current approach)
- `temp/test_write.txt` (alternative subdirectory)
- `debug/test_write.txt` (debug subdirectory)
- `logs/test_write.txt` (logs subdirectory)

### **5. Alternative Directory Approaches**
- Tests Love2D's save directory approach
- Tests identity-based paths
- Tests mounted directory scenarios

### **6. Capability Summary**
- Determines which filesystem operations work
- Identifies the recommended base path for file operations
- Provides clear guidance for fixing the issue

## **How to Run the Test**

### **Step 1: Launch Balatro**
1. Close any running Balatro instances
2. Launch Balatro through Steam
3. Wait for the main menu to appear

### **Step 2: Enable BalatroMCP Mod**
1. Go to Balatro's mods menu
2. Ensure BalatroMCP is enabled
3. Start a new game or continue existing game

### **Step 3: Monitor Output**
The diagnostic will run automatically when the mod loads. Look for:

**Console Output** (if visible):
```
BalatroMCP: Running comprehensive filesystem diagnostic...
=== LOVE2D FILESYSTEM COMPREHENSIVE DIAGNOSTIC ===
```

**Expected Output Sections:**
1. `1. TESTING LOVE2D AVAILABILITY`
2. `2. LOVE2D VERSION INFO`
3. `3. DIRECTORY INFORMATION`
4. `4. CURRENT DIRECTORY CONTENTS`
5. `5. WRITE PERMISSION TESTS`
6. `6. ALTERNATIVE DIRECTORY TESTS`
7. `7. FILESYSTEM CAPABILITY SUMMARY`
8. `8. ENVIRONMENT-SPECIFIC CHECKS`

### **Step 4: Check for Log Files**
The diagnostic may create log files in various locations. Check:
- Balatro's save directory
- Current working directory
- Any subdirectories that were successfully created

### **Step 5: Exit and Report**
After running the diagnostic:
1. Exit Balatro cleanly
2. Report all console output you observed
3. Check for any created log files
4. Note any error messages or crashes

## **Expected Key Information**
The diagnostic should reveal:

### **Critical Findings:**
- ✅ **Working Directory**: What directory Love2D thinks it's in
- ✅ **Save Directory**: Love2D's designated save location
- ✅ **Write Permissions**: Which paths allow file creation
- ✅ **Recommended Path**: The correct base path to use

### **Failure Indicators:**
- ❌ `love.filesystem NOT available`
- ❌ `Could not get working directory`
- ❌ `File write: FAILED` for all test paths
- ❌ `NONE FOUND` for recommended base path

## **What to Report Back**
Please provide:

1. **Full console output** from the diagnostic (if visible)
2. **Any error messages** that appeared
3. **Log files** found in Balatro directories
4. **Game behavior** - did it crash, freeze, or run normally?
5. **Recommended path** reported by the diagnostic

## **Next Steps After Diagnostic**
Based on the results, we will:
1. **Identify the working filesystem path** for Love2D in Balatro
2. **Update the FileIO configuration** to use the correct path
3. **Fix the file communication system** between mod and server
4. **Restore debug logging functionality**

Run the test and report back with the detailed diagnostic output!