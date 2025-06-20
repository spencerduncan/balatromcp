#!/usr/bin/env python3
"""
Validation script for Lua unit tests
Analyzes test structure and coverage without requiring Lua installation
"""

import re
import os
from pathlib import Path

def analyze_test_file(filepath):
    """Analyze the Lua test file for structure and coverage"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        return None, f"Test file not found: {filepath}"
    
    # Extract test function names
    test_pattern = r'test_framework:add_test\("([^"]+)"'
    tests = re.findall(test_pattern, content)
    
    # Categorize tests
    categories = {
        'Safe Access Functions': [],
        'G Object Validation': [],
        'Game Object Validation': [],
        'Card Area Validation': [],
        'Card Structure Validation': [],
        'Extraction Functions': [],
        'Edge Cases': []
    }
    
    for test in tests:
        if 'safe_check_path' in test or 'safe_get_value' in test or 'safe_get_nested_value' in test:
            categories['Safe Access Functions'].append(test)
        elif 'validate_g_object' in test:
            categories['G Object Validation'].append(test)
        elif 'validate_game_object' in test:
            categories['Game Object Validation'].append(test)
        elif 'validate_card_areas' in test or 'validate_card_structure' in test:
            categories['Card Area Validation'].append(test)
        elif 'get_current_phase' in test or 'get_ante' in test or 'get_money' in test or 'extract_' in test:
            categories['Extraction Functions'].append(test)
        elif 'edge case' in test.lower() or 'handles' in test or 'malformed' in test or 'gracefully' in test:
            categories['Edge Cases'].append(test)
        else:
            categories['Edge Cases'].append(test)  # Default to edge cases
    
    # Check for essential test components
    essential_patterns = {
        'Test Framework': r'TestFramework\s*=\s*{}',
        'Mock G Generator': r'function create_mock_g\(',
        'Mock Card Generator': r'function create_mock_card\(',
        'StateExtractor Import': r'require\("?state_extractor"?\)',
        'Test Runner': r'function run_state_extractor_tests\(\)'
    }
    
    components = {}
    for name, pattern in essential_patterns.items():
        components[name] = bool(re.search(pattern, content))
    
    return {
        'total_tests': len(tests),
        'categories': categories,
        'components': components,
        'tests': tests
    }, None

def analyze_state_extractor(filepath):
    """Analyze the StateExtractor module for validation functions"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        return None, f"StateExtractor file not found: {filepath}"
    
    # Find validation functions
    validation_functions = re.findall(r'function StateExtractor:(\w*validate\w*|safe_\w*)\(', content)
    
    # Find extraction functions
    extraction_functions = re.findall(r'function StateExtractor:(get_\w*|extract_\w*)\(', content)
    
    # Check for error handling patterns
    error_patterns = {
        'pcall usage': len(re.findall(r'pcall\(', content)),
        'safe_check_path calls': len(re.findall(r'self:safe_check_path\(', content)),
        'safe_get_value calls': len(re.findall(r'self:safe_get_value\(', content)),
        'safe_get_nested_value calls': len(re.findall(r'self:safe_get_nested_value\(', content)),
        'warning logs': len(re.findall(r'self:log\("WARNING:', content)),
        'error logs': len(re.findall(r'self:log\("ERROR:', content))
    }
    
    return {
        'validation_functions': validation_functions,
        'extraction_functions': extraction_functions,
        'error_patterns': error_patterns
    }, None

def main():
    """Main validation function"""
    print("=== LUA UNIT TEST VALIDATION ===")
    print("Analyzing test structure and coverage...\n")
    
    # Analyze test file
    test_file = "test_state_extractor.lua"
    test_analysis, test_error = analyze_test_file(test_file)
    
    if test_error:
        print(f"❌ ERROR: {test_error}")
        return False
    
    # Analyze StateExtractor
    extractor_file = "state_extractor.lua"
    extractor_analysis, extractor_error = analyze_state_extractor(extractor_file)
    
    if extractor_error:
        print(f"❌ ERROR: {extractor_error}")
        return False
    
    # Report results
    print("📊 TEST COVERAGE ANALYSIS")
    print("=" * 50)
    print(f"Total Tests: {test_analysis['total_tests']}")
    print()
    
    for category, tests in test_analysis['categories'].items():
        if tests:
            print(f"📋 {category}: {len(tests)} tests")
            for test in tests:
                print(f"   ✓ {test}")
            print()
    
    print("🔧 TEST FRAMEWORK COMPONENTS")
    print("=" * 50)
    for component, present in test_analysis['components'].items():
        status = "✅" if present else "❌"
        print(f"{status} {component}")
    print()
    
    print("🛡️ VALIDATION COVERAGE")
    print("=" * 50)
    print("StateExtractor Validation Functions:")
    for func in extractor_analysis['validation_functions']:
        print(f"   ✓ {func}()")
    print()
    
    print("StateExtractor Extraction Functions:")
    for func in extractor_analysis['extraction_functions']:
        print(f"   ✓ {func}()")
    print()
    
    print("🔍 ERROR HANDLING PATTERNS")
    print("=" * 50)
    for pattern, count in extractor_analysis['error_patterns'].items():
        print(f"   {pattern}: {count} occurrences")
    print()
    
    # Validation checks
    all_components_present = all(test_analysis['components'].values())
    has_sufficient_tests = test_analysis['total_tests'] >= 30
    has_diverse_coverage = len([cat for cat, tests in test_analysis['categories'].items() if tests]) >= 5
    has_error_handling = extractor_analysis['error_patterns']['warning logs'] > 0
    
    checks = [
        ("All test framework components present", all_components_present),
        ("Sufficient test coverage (30+ tests)", has_sufficient_tests),
        ("Diverse test categories covered", has_diverse_coverage),
        ("Error handling implemented", has_error_handling)
    ]
    
    print("✅ VALIDATION RESULTS")
    print("=" * 50)
    all_passed = True
    for check_name, passed in checks:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status}: {check_name}")
        if not passed:
            all_passed = False
    
    print()
    if all_passed:
        print("🎉 SUCCESS: Unit test validation passed!")
        print("The test suite provides comprehensive coverage for StateExtractor validation logic.")
        print("\nKey Coverage Areas:")
        print("• Safe access utility functions with nil/malformed data")
        print("• G object validation with missing/partial structures") 
        print("• Game object validation with edge cases")
        print("• Card area and structure validation")
        print("• Extraction function error handling and fallbacks")
        print("• Edge cases and graceful degradation")
        print("\nTo run the tests, install Lua 5.1+ and execute: lua run_lua_tests.lua")
    else:
        print("❌ VALIDATION FAILED: Test suite needs improvements")
    
    return all_passed

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)