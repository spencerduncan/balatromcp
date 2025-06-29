# MCP Server Component Documentation

## Overview
This directory contains the Model Context Protocol (MCP) server implementation that provides compatibility with the BalatroMCP mod's file-based interface.

## Review Lessons Learned
For implementation insights and review best practices for MCP server development, see:
- [MCP Server Review Lessons](./MCP_SERVER_REVIEW_LESSONS.md) - Patterns for TypeScript/ESM MCP implementations and file interface compatibility

## Architecture
The MCP server follows a clean separation of concerns:
- **Protocol Layer**: MCP SDK handles protocol communication
- **File Interface**: BalatroMCPFileInterface manages file operations
- **Type Safety**: Comprehensive TypeScript interfaces throughout

## Key Design Principles
- Real-time file watching for live updates
- Graceful error handling with fallbacks
- Complete BalatroMCP message format compatibility
- Resource cleanup and proper shutdown handling

## Testing Strategy
- Unit tests for component isolation
- Integration tests for end-to-end compatibility
- File system operation testing with temporary directories
- Error scenario coverage for robustness

Refer to the main project CLAUDE.md for additional development guidelines and testing instructions.