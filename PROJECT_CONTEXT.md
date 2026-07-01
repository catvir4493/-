# Project Context: Midnight Wish Mart

## Game Summary
This is a 2D narrative shop-management puzzle game.

The player runs a mysterious convenience store that only opens at midnight. Customers describe wishes or emotional problems instead of directly asking for products. The player chooses 1–3 items, and the game scores the result based on item tags and customer needs.

## Core Loop
Customer request → Select items → Score result → Get money → Restock → Next night

## MVP Scope
The MVP must include:
- Main menu
- Shop scene
- Customer dialogue
- Item selection
- Tag-based scoring
- Combo detection
- Money system
- Restock system
- Save/load system

## Do Not Add Yet
Do not add:
- Player movement
- Combat
- Open world map
- Multiplayer
- Mobile controls
- Complex animations
- Procedural generation

## Technical Direction
Use Godot.
Use fixed-screen UI gameplay.
Use JSON data for items, customers, combos, and nights.

## Main Systems
- GameManager
- DataManager
- InventorySystem
- CustomerSystem
- ScoreSystem
- ComboSystem
- SaveManager

## Coding Rules
- Keep systems separated.
- Do not hard-code item or customer data inside scene scripts.
- Load gameplay data from JSON files.
- Make UI temporary first; polish later.
- MVP first, art later.

## Current Priority
Build a playable prototype:
MainMenu → ShopScene → Score feedback → ResultScene → RestockScene → Next Night.