#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates actions.json files for testing BalatroMCP action execution
.DESCRIPTION
    Generates properly formatted actions.json files with correct structure
    for testing various action types in the BalatroMCP system.
.PARAMETER Action
    The type of action to create (skip_blind, select_blind, play_hand, discard_cards, go_to_shop, buy_item, sell_joker, sell_consumable, use_consumable, reorder_jokers, reroll_boss, reroll_shop, sort_hand_by_rank, sort_hand_by_suit, move_playing_card, select_pack_offer, go_next, diagnose_blind_progression, diagnose_blind_activation)
.PARAMETER Sequence
    The sequence ID for the action (required)
.PARAMETER Target
    Target for actions that require it (e.g., joker_index for sell_joker, shop_index for buy_item, item_id for use_consumable)
.PARAMETER Cards
    Comma-separated list of card indices for play_hand/discard_cards actions, or from_index,to_index for move_playing_card
.PARAMETER BlindType
    Type of blind to select (small, big, boss) for select_blind action
.PARAMETER NewOrder
    Comma-separated list of joker IDs in new order for reorder_jokers action
.PARAMETER OutputPath
    Path to output the actions.json file (default: ../../AppData/Roaming/Balatro/shared/actions.json)
.EXAMPLE
    .\create-action.ps1 -Action skip_blind -Sequence 35
.EXAMPLE
    .\create-action.ps1 -Action select_blind -Sequence 36 -BlindType big
.EXAMPLE
    .\create-action.ps1 -Action play_hand -Sequence 37 -Cards "0,1,2,3,4"
.EXAMPLE
    .\create-action.ps1 -Action discard_cards -Sequence 38 -Cards "0,1,2"
.EXAMPLE
    .\create-action.ps1 -Action sell_joker -Sequence 39 -Target 0
.EXAMPLE
    .\create-action.ps1 -Action buy_item -Sequence 40 -Target 0
.EXAMPLE
    .\create-action.ps1 -Action use_consumable -Sequence 41 -Target 123456
.EXAMPLE
    .\create-action.ps1 -Action move_playing_card -Sequence 42 -Cards "0,4"
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("skip_blind", "select_blind", "play_hand", "discard_cards", "go_to_shop", "buy_item", "sell_joker", "sell_consumable", "use_consumable", "reorder_jokers", "reroll_boss", "reroll_shop", "sort_hand_by_rank", "sort_hand_by_suit", "move_playing_card", "select_pack_offer", "go_next", "diagnose_blind_progression", "diagnose_blind_activation")]
    [string]$Action,
    
    [Parameter(Mandatory=$true)]
    [int]$Sequence,
    
    [Parameter(Mandatory=$false)]
    [string]$Target,
    
    [Parameter(Mandatory=$false)]
    [string]$Cards,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("small", "big", "boss")]
    [string]$BlindType,
    
    [Parameter(Mandatory=$false)]
    [string]$NewOrder,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "../../AppData/Roaming/Balatro/shared/actions.json"
)

# Function to create the base action structure
function New-ActionData {
    param(
        [string]$ActionType,
        [int]$SequenceId
    )
    
    return @{
        action_type = $ActionType
        sequence_id = $SequenceId
    }
}

# Create the action data based on the action type
$actionData = New-ActionData -ActionType $Action -SequenceId $Sequence

# Add action-specific parameters
switch ($Action) {
    "select_blind" {
        if (-not $BlindType) {
            Write-Error "BlindType is required for select_blind action"
            exit 1
        }
        $actionData.blind_type = $BlindType
    }
    
    "play_hand" {
        if (-not $Cards) {
            Write-Error "Cards parameter is required for play_hand action"
            exit 1
        }
        $cardIndices = $Cards -split "," | ForEach-Object { [int]$_.Trim() }
        $actionData.card_indices = $cardIndices
    }
    
    "discard_cards" {
        if (-not $Cards) {
            Write-Error "Cards parameter is required for discard_cards action"
            exit 1
        }
        $cardIndices = $Cards -split "," | ForEach-Object { [int]$_.Trim() }
        $actionData.card_indices = $cardIndices
    }
    
    "buy_item" {
        if ($null -eq $Target) {
            Write-Error "Target (shop_index) is required for buy_item action"
            exit 1
        }
        $actionData.shop_index = [int]$Target
    }
    
    "sell_joker" {
        if ($null -eq $Target) {
            Write-Error "Target (joker_index) is required for sell_joker action"
            exit 1
        }
        $actionData.joker_index = [int]$Target
    }
    
    "sell_consumable" {
        if ($null -eq $Target) {
            Write-Error "Target (consumable_index) is required for sell_consumable action"
            exit 1
        }
        $actionData.consumable_index = [int]$Target
    }
    
    "use_consumable" {
        if ($null -eq $Target) {
            Write-Error "Target (item_id) is required for use_consumable action"
            exit 1
        }
        $actionData.consumable_index = [int]$Target
    }
    
    "select_pack_offer" {
        if ($null -eq $Target) {
            Write-Error "Target (pack_index) is required for select_pack_offer action"
            exit 1
        }
        $actionData.pack_index = [int]$Target
    }
    
    "move_playing_card" {
        if (-not $Cards) {
            Write-Error "Cards parameter is required for move_playing_card action (format: from_index,to_index)"
            exit 1
        }
        $indices = $Cards -split "," | ForEach-Object { [int]$_.Trim() }
        if ($indices.Length -ne 2) {
            Write-Error "move_playing_card requires exactly 2 indices: from_index,to_index"
            exit 1
        }
        $actionData.from_index = $indices[0]
        $actionData.to_index = $indices[1]
    }
    
    "reorder_jokers" {
        if (-not $Cards) {
            Write-Error "Cards parameter is required for reorder_jokers action (format: from_index,to_index)"
            exit 1
        }
        $indices = $Cards -split "," | ForEach-Object { [int]$_.Trim() }
        if ($indices.Length -ne 2) {
            Write-Error "reorder_jokers requires exactly 2 indices: from_index,to_index"
            exit 1
        }
        $actionData.from_index = $indices[0]
        $actionData.to_index = $indices[1]
    }
}

# Create the complete message structure with full message envelope
$timestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$message = @{
    timestamp = $timestamp
    sequence_id = $Sequence
    message_type = "action"
    data = $actionData
}

# Convert to JSON with compact formatting
$jsonOutput = $message | ConvertTo-Json -Depth 10 -Compress

# Ensure the output directory exists
$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Write the JSON to the file (UTF-8 without BOM)
[System.IO.File]::WriteAllText($OutputPath, $jsonOutput, [System.Text.UTF8Encoding]::new($false))

Write-Host "Created action file: $OutputPath"
Write-Host "Action: $Action (sequence: $Sequence)"

# Display the generated JSON for verification
Write-Host "`nGenerated JSON:"
Write-Host $jsonOutput