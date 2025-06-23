@echo off
REM Quick test action generator for BalatroMCP
REM Usage: test-actions.bat [action_type] [sequence] [additional_params...]

if "%1"=="" (
    echo Usage: test-actions.bat [action_type] [sequence] [additional_params...]
    echo.
    echo Available action types:
    echo   skip_blind [sequence]
    echo   select_blind [sequence] [small/big/boss]
    echo   play_hand [sequence] [card_ids_comma_separated]
    echo   discard_hand [sequence] [card_ids_comma_separated]
    echo   reroll_shop [sequence]
    echo   buy_item [sequence] [item_index]
    echo   sell_joker [sequence] [joker_id]
    echo   use_consumable [sequence] [consumable_id]
    echo   reorder_jokers [sequence] [joker_ids_comma_separated]
    echo.
    echo Examples:
    echo   test-actions.bat skip_blind 35
    echo   test-actions.bat select_blind 36 big
    echo   test-actions.bat play_hand 37 "1,2,3,4,5"
    echo   test-actions.bat sell_joker 38 123.456
    echo   test-actions.bat buy_item 39 0
    goto :eof
)

set ACTION_TYPE=%1
set SEQUENCE=%2

if "%ACTION_TYPE%"=="skip_blind" (
    powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action skip_blind -Sequence %SEQUENCE%
    goto :eof
)

if "%ACTION_TYPE%"=="select_blind" (
    if "%3"=="" (
        echo Error: BlindType required for select_blind. Use: small, big, or boss
        goto :eof
    )
    powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action select_blind -Sequence %SEQUENCE% -BlindType %3
    goto :eof
)

if "%ACTION_TYPE%"=="play_hand" (
    if "%3"=="" (
        echo Error: Card IDs required for play_hand. Use comma-separated list like "1,2,3,4,5"
        goto :eof
    )
    powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action play_hand -Sequence %SEQUENCE% -Cards %3
    goto :eof
)

if "%ACTION_TYPE%"=="discard_hand" (
    if "%3"=="" (
        echo Error: Card IDs required for discard_hand. Use comma-separated list like "1,2,3"
        goto :eof
    )
    powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action discard_hand -Sequence %SEQUENCE% -Cards %3
    goto :eof
)

if "%ACTION_TYPE%"=="reroll_shop" (
    powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action reroll_shop -Sequence %SEQUENCE%
    goto :eof
)

if "%ACTION_TYPE%"=="buy_item" (
    if "%3"=="" (
        echo Error: Item index required for buy_item. Use shop position like 0, 1, 2, etc.
        goto :eof
    )
    powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action buy_item -Sequence %SEQUENCE% -Target %3
    goto :eof
)

if "%ACTION_TYPE%"=="sell_joker" (
    if "%3"=="" (
        echo Error: Joker ID required for sell_joker. Use joker ID like 123.456
        goto :eof
    )
    powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action sell_joker -Sequence %SEQUENCE% -Target %3
    goto :eof
)

if "%ACTION_TYPE%"=="use_consumable" (
    if "%3"=="" (
        echo Error: Consumable ID required for use_consumable. Use consumable ID like 789.123
        goto :eof
    )
    powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action use_consumable -Sequence %SEQUENCE% -Target %3
    goto :eof
)

if "%ACTION_TYPE%"=="reorder_jokers" (
    if "%3"=="" (
        echo Error: Joker order required for reorder_jokers. Use comma-separated joker IDs like "123.1,456.2,789.3"
        goto :eof
    )
    powershell -ExecutionPolicy Bypass -File create-action.ps1 -Action reorder_jokers -Sequence %SEQUENCE% -NewOrder %3
    goto :eof
)

echo Error: Unknown action type "%ACTION_TYPE%"
echo Run without parameters to see available action types.