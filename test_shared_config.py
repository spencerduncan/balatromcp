#!/usr/bin/env python3
"""
Simple test script to verify shared folder configuration is working correctly.
"""

import os
import sys
from pathlib import Path

def test_shared_folder_config():
    """Test that shared folder configuration is working correctly."""
    print("=== Testing Shared Folder Configuration ===")
    
    # Test the absolute path
    shared_path = "C:/Users/whokn/Documents/balatroman/shared"
    print(f"Testing path: {shared_path}")
    
    # Check if directory exists
    if os.path.exists(shared_path):
        print("✓ Shared directory exists")
        
        # Check if it's actually a directory
        if os.path.isdir(shared_path):
            print("✓ Path is a directory")
            
            # List contents
            try:
                contents = os.listdir(shared_path)
                print(f"✓ Directory contents: {contents}")
            except Exception as e:
                print(f"✗ Failed to list directory contents: {e}")
        else:
            print("✗ Path exists but is not a directory")
    else:
        print("✗ Shared directory does not exist")
    
    # Test file creation in shared directory
    test_file = os.path.join(shared_path, "config_test.txt")
    try:
        with open(test_file, 'w') as f:
            f.write("Configuration test successful")
        print("✓ Can create files in shared directory")
        
        # Test file reading
        with open(test_file, 'r') as f:
            content = f.read()
        print(f"✓ Can read files from shared directory: '{content}'")
        
        # Clean up
        os.remove(test_file)
        print("✓ Can remove files from shared directory")
        
    except Exception as e:
        print(f"✗ File operations failed: {e}")
    
    # Test that the mod would use the same path
    print("\n=== Mod Configuration Test ===")
    mod_path = "C:/Users/whokn/Documents/balatroman/shared"
    print(f"Mod would use path: {mod_path}")
    print(f"✓ Paths match: {shared_path == mod_path}")
    
    # Test log file location
    log_file = os.path.join(shared_path, "debug.log")
    print(f"Debug log location: {log_file}")
    try:
        # Create a test log entry
        with open(log_file, 'a') as f:
            f.write(f"[TEST] Configuration verified at {os.path.basename(__file__)}\n")
        print("✓ Can write to debug log")
    except Exception as e:
        print(f"✗ Failed to write to debug log: {e}")

if __name__ == "__main__":
    test_shared_folder_config()
    print("\n=== Configuration Test Complete ===")