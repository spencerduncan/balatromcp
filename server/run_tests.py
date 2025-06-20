"""
Test runner script for Balatro MCP Server unit tests.
Provides easy way to run tests with different configurations.
"""

import sys
import subprocess
import argparse
from pathlib import Path


def run_tests(
    test_path: str = "tests/",
    verbose: bool = False,
    coverage: bool = False,
    specific_test: str = None,
    markers: str = None,
    exit_on_failure: bool = True,
):
    """
    Run pytest with specified configuration.
    
    Args:
        test_path: Path to test directory or specific test file
        verbose: Enable verbose output
        coverage: Run with coverage reporting
        specific_test: Run a specific test function
        markers: Run tests with specific markers
        exit_on_failure: Exit script if tests fail
    """
    
    # Base pytest command
    cmd = ["python", "-m", "pytest"]
    
    # Add test path
    cmd.append(test_path)
    
    # Add verbosity
    if verbose:
        cmd.append("-v")
    else:
        cmd.append("-q")
    
    # Add coverage
    if coverage:
        cmd.extend([
            "--cov=server",
            "--cov-report=term-missing",
            "--cov-report=html:htmlcov",
            "--cov-fail-under=90"
        ])
    
    # Add specific test
    if specific_test:
        cmd.extend(["-k", specific_test])
    
    # Add markers
    if markers:
        cmd.extend(["-m", markers])
    
    # Add other useful options
    cmd.extend([
        "--tb=short",
        "--strict-markers",
        "--disable-warnings"
    ])
    
    print(f"Running command: {' '.join(cmd)}")
    print("-" * 60)
    
    # Run tests
    result = subprocess.run(cmd, cwd=Path(__file__).parent)
    
    if result.returncode != 0 and exit_on_failure:
        print(f"\nTests failed with exit code {result.returncode}")
        sys.exit(result.returncode)
    
    return result.returncode


def main():
    """Main entry point for test runner."""
    parser = argparse.ArgumentParser(description="Run Balatro MCP Server tests")
    
    parser.add_argument(
        "test_path",
        nargs="?",
        default="tests/",
        help="Path to test directory or specific test file"
    )
    
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    
    parser.add_argument(
        "-c", "--coverage",
        action="store_true",
        help="Run with coverage reporting"
    )
    
    parser.add_argument(
        "-k", "--keyword",
        help="Run tests matching keyword expression"
    )
    
    parser.add_argument(
        "-m", "--markers",
        help="Run tests with specific markers"
    )
    
    parser.add_argument(
        "--no-exit",
        action="store_true",
        help="Don't exit on test failure"
    )
    
    # Predefined test suites
    parser.add_argument(
        "--schemas",
        action="store_true",
        help="Run only schema tests"
    )
    
    parser.add_argument(
        "--file-io",
        action="store_true",
        help="Run only file I/O tests"
    )
    
    parser.add_argument(
        "--state-manager",
        action="store_true",
        help="Run only state manager tests"
    )
    
    parser.add_argument(
        "--action-handler",
        action="store_true",
        help="Run only action handler tests"
    )
    
    parser.add_argument(
        "--main-server",
        action="store_true",
        help="Run only main server tests"
    )
    
    parser.add_argument(
        "--interfaces",
        action="store_true",
        help="Run only interface tests"
    )
    
    args = parser.parse_args()
    
    # Handle predefined suites
    if args.schemas:
        args.test_path = "tests/test_schemas.py"
    elif args.file_io:
        args.test_path = "tests/test_file_io.py"
    elif args.state_manager:
        args.test_path = "tests/test_state_manager.py"
    elif args.action_handler:
        args.test_path = "tests/test_action_handler.py"
    elif args.main_server:
        args.test_path = "tests/test_main.py"
    elif args.interfaces:
        args.test_path = "tests/test_interfaces.py"
    
    # Run tests
    return run_tests(
        test_path=args.test_path,
        verbose=args.verbose,
        coverage=args.coverage,
        specific_test=args.keyword,
        markers=args.markers,
        exit_on_failure=not args.no_exit,
    )


if __name__ == "__main__":
    sys.exit(main())