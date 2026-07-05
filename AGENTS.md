# AGENTS.md

## Project Identity

This project is a brand-new standalone Godot game called **深夜愿望便利店** / **Midnight Wish Mart**.

It must not be connected to any previous or unrelated project. Do not introduce concepts from other game ideas, including forging, swordsmiths, magic blades, old game repair, Qinglu Town, code fragments, RPG combat, large maps, or free exploration.

## Game Overview

**Genre:** 2D narrative management puzzle game.

More specifically:

- shop management simulation
- item-combination puzzle
- short customer story collection
- fixed-screen UI-based gameplay

The player runs a convenience store that only appears between midnight and early morning. Customers do not directly say what they want to buy. Instead, they describe a wish, worry, fear, regret, or vague emotional need.

The player must understand the customer and choose **1–3 items** from the shelf. The selected items are evaluated through item tags, customer required tags, avoided tags, and special item combinations.

The core fantasy is:

> Understand people through ordinary convenience-store items.

## Core Experience

The game should feel:

- late-night
- urban
- quiet
- warm
- slightly strange
- healing
- lightly suspenseful
- a little darkly humorous
- lonely but comforting

The game is not about complex economic management. It is about interpreting people, experimenting with item combinations, receiving emotional feedback, and slowly uncovering why this shop only appears at midnight.

## Development Principles

Always prioritize a playable MVP over visual polish.

Follow these rules:

1. Build a working game loop first.
2. Keep all systems modular and easy to expand.
3. Do not implement free movement in the first version.
4. Do not implement combat.
5. Do not implement a large map.
6. Use temporary UI placeholders before final art.
7. Use `Panel`, `Label`, `Button`, and simple placeholder graphics for MVP screens.
8. Data should come from JSON or Godot Resources when practical.
9. Do not hardcode large item, customer, combo, or dialogue datasets directly into UI scripts.
10. Keep code clear and beginner-maintainable.
11. Avoid putting all game logic into one script.
12. Systems are more important than art in the first version.

## MVP Goal

The first version must answer one question:

> Will the player want to keep serving customers and trying different item combinations?

The MVP must include:

- one convenience-store main interface
- one customer display area
- one item-selection interface
- 20 items
- 30 customer requests
- tag-based scoring
- special item combinations
- money system
- simple restocking system
- night result screen
- local save system

The MVP must not include:

- large map
- free movement
- combat
- complex animation
- multiple endings
- full voice acting
- complex AI
- online multiplayer
- achievement system
- mobile adaptation
- large CG set
- complex shop decoration

## Core Game Loop

The main gameplay loop is:

```text
Serve customer → Understand request → Choose items → Receive feedback → Earn money → Restock → Start next night
```

The detailed night flow is:

```text
1. Start night shift
2. Customer appears
3. Customer says a wish, worry, or vague request
4. Player checks available shelf items
5. Player selects 1–3 items
6. Game evaluates item tags against customer needs
7. Customer reacts
8. Player receives score, money, and possibly story clues
9. Next customer appears
10. After all customers, show night result screen
11. Player restocks items
12. Start next night
```

## Recommended Engine and Format

Use **Godot 4.x**.

Use a fixed-screen 2D UI format for the MVP:

```text
Convenience-store background + customer portrait + item cards + dialogue box + result screen
```

Use:

- GDScript
- Control nodes for UI
- Node-based scene structure
- JSON or Resources for data
- simple scene switching
- local JSON save files

Avoid:

- 3D
- unnecessary physics
- free-roaming player movement
- complex inheritance frameworks
- large abstract architecture
- premature visual polish

## Screen Structure

### Main Shop Screen

The shop screen should roughly contain:

```text
Top: night number / current time / money
Middle: customer portrait / customer name / customer dialogue
Right: item shelf / item card list
Bottom: selected items / confirm button / clear button
```

### Customer Feedback Screen or Panel

After submission, show:

```text
customer reaction
score grade
money earned
triggered combo, if any
new archive unlock, if any
```

### Night Result Screen

Show:

```text
Night X ended
total income
service rating
perfect count
fail count
new items
new customer archives
button to restock
```

### Restock Screen

Show:

```text
item list
current stock
max stock
buy price
buy button
remaining money
start next night button
```

## Visual Direction

MVP can use placeholder art.

Final art direction should be:

- 2D pixel art, hand-drawn 2D, or UI-card style
- warm yellow convenience-store lighting
- dark blue / black night outside
- rainy urban street feeling
- cashier counter
- refrigerator glow
- lonely city mood
- slight urban-legend atmosphere

Do not make the game look like a fantasy RPG, combat game, or map-exploration game.

## Audio Direction

MVP only needs simple audio:

- late-night convenience-store loop BGM
- door bell
- cash register
- item select sound
- satisfied customer sound
- dissatisfied customer sound
- night result sound

Later polish can add:

- refrigerator hum
- rain ambience
- distant street noise
- fluorescent light buzz
- plastic bag sound
- soft UI click sounds

## Data-Driven Item System

Item data should include:

```text
id
name
description
buy_price
sell_price
tags
rarity
unlock_day
stock
max_stock
```

Example item:

```json
{
  "id": "coffee",
  "name": "罐装咖啡",
  "description": "便利店最普通的罐装咖啡，喝完会清醒，也会更焦虑。",
  "buy_price": 3,
  "sell_price": 6,
  "tags": ["清醒", "焦虑", "短效"],
  "rarity": "common",
  "unlock_day": 1,
  "max_stock": 10
}
```

## First Version Item List

The first version should contain these 20 items:

```text
1. 罐装咖啡
2. 温牛奶
3. 薄荷糖
4. 黑伞
5. 红色打火机
6. 创可贴
7. 旧照片
8. 车票
9. 眼罩
10. 纸巾
11. 黑巧克力
12. 一次性相机
13. 空白明信片
14. 电池
15. 手电筒
16. 便宜香水
17. 过期杂志
18. 幸运贴纸
19. 饭团
20. 硬币
```

## First Version Tag Pool

Keep the first tag pool under 20 tags when possible:

```text
清醒
睡眠
冷静
勇气
安慰
隐藏
保护
回忆
悲伤
真实
冲动
危险
温和
短效
长期
孤独
希望
逃避
遗忘
连接
```

## Customer Request System

Customer requests should include:

```text
id
customer_name
customer_type
dialogue
required_tags
avoid_tags
difficulty
base_reward
story_id
repeatable
```

Example customer request:

```json
{
  "id": "student_exam_01",
  "customer_name": "黑眼圈学生",
  "customer_type": "student",
  "dialogue": "明天有一场很重要的考试，但我现在脑子像坏掉了一样。",
  "required_tags": ["清醒", "冷静", "短效"],
  "avoid_tags": ["睡眠", "冲动"],
  "difficulty": 1,
  "base_reward": 8,
  "story_id": "student_story",
  "repeatable": false
}
```

## First Version Customer Types

Use these customer archetypes first:

```text
1. 黑眼圈学生
2. 加班职员
3. 湿透的男人
4. 穿红裙的女人
5. 沉默老人
6. 戴口罩的少年
7. 迷路的小孩
8. 失眠的司机
9. 忘记名字的客人
10. 上一任店员
```

## Item Selection Rules

The player must be able to select items from the shelf.

Rules:

1. The player faces one customer at a time.
2. The player may select 1–3 items.
3. Selected items are stored in `selected_items`.
4. Selected items can be canceled or cleared.
5. Items with 0 stock cannot be selected.
6. On confirmation, selected item stock is consumed.
7. After confirmation, pass selected items to `ScoreSystem`.

UI feedback:

- selected items are highlighted
- out-of-stock items are disabled or greyed out
- if more than 3 items are selected, show: `最多只能选择 3 件商品。`
- if confirm is pressed with no item selected, show: `请至少选择 1 件商品。`

## Score System

The score is based on:

1. matching customer `required_tags`
2. avoiding customer `avoid_tags`
3. base points per selected item
4. special combo bonus

Rules:

```text
Each matched required tag: +20
Each avoid tag present: -20
Each selected item: +5
Triggered combo: +combo score bonus
Clamp final score between 0 and 100
```

Grade rules:

```text
90–100 = perfect
70–89 = good
40–69 = normal
0–39 = fail
```

`ScoreSystem` should return:

```text
score
grade
matched_tags
bad_tags
combo_result
```

Customer feedback examples:

```text
perfect: “谢谢。我好像知道该怎么做了。”
good: “这应该有用。至少今晚有用。”
normal: “也许吧……我会试试。”
fail: “你根本没听懂我在说什么。”
```

## Special Combo System

Special combos are a key addictive element.

They should encourage experimentation with item combinations.

Combo data should include:

```text
combo_id
combo_name
required_item_ids
bonus_tags
score_bonus
special_dialogue
```

First version combos:

```text
1. 咖啡 + 薄荷糖 = 熬夜套餐
2. 牛奶 + 旧照片 = 怀旧套餐
3. 黑伞 + 车票 = 逃跑套餐
4. 打火机 + 创可贴 = 冲动后的补救
5. 纸巾 + 牛奶 = 今晚先哭吧
6. 手电筒 + 电池 = 找路套餐
7. 空白明信片 + 便宜香水 = 没寄出的告白
8. 饭团 + 幸运贴纸 = 明天会好一点
```

## Money System

Money comes from serving customers.

MVP income formula:

```text
final_income = selected_items_sell_price_total + score_bonus
```

Score bonus:

```text
perfect: +10
good: +5
normal: +0
fail: -2
```

Failure should not block progress. Avoid harsh penalties that make the player unable to continue.

## Restock System

After each night, the player enters the restock screen.

Rules:

1. Items have buy prices.
2. Items have max stock.
3. If money is insufficient, the item cannot be bought.
4. If stock is already at max stock, the item cannot be bought.
5. Buying an item subtracts money and adds stock.
6. Pressing `Next Night` starts the next night.

## Night System

The game progresses by night number.

Recommended MVP night structure:

```text
Night 1: 5 customers
Night 2: 6 customers
Night 3: 7 customers
Night 4: 8 customers
Night 5: special story night
```

Night result screen should include:

```text
customers served
perfect services
fail count
total income
new unlocked items
new customer archives
shop rating
```

Shop rating text:

```text
S: 今晚的店像一个奇迹。
A: 顾客们记住了这家店。
B: 还算不错的一晚。
C: 有些人失望地离开了。
D: 这家店今晚像个错误。
```

## Save System

Save data should include:

```text
current_day
money
inventory
unlocked_items
seen_customers
customer_story_progress
discovered_combos
```

Use local JSON save data for the MVP.

Main menu should support:

- New Game
- Continue

If no save exists, the Continue button should be disabled.

Auto-save:

- after night result
- before entering the next night

## Story Direction

The convenience store appears only from 00:00 to 04:00.

It has no fixed address and is not shown on maps. Only people who truly need something can enter.

The player is the new night-shift clerk. The previous clerk is missing.

The story should be revealed through:

- recurring customers
- updated customer archives
- item description changes
- strange midnight radio broadcasts
- notes left at the cashier counter
- items restocking by themselves
- gradual changes outside the shop window

Main mysteries:

1. Why does the store only appear after midnight?
2. Why can certain customers find it?
3. Where did the previous clerk go?
4. Where do the items come from?
5. Why did the player become the night-shift clerk?

MVP story goal:

- establish that this is a strange convenience store
- serve a group of midnight customers
- include 2–3 recurring customers
- make Night 5 include a special customer
- end with a mystery hook

Night 5 special customer:

```text
上一任店员：“我想买一样东西。”
玩家：“您需要什么？”
上一任店员：“我想买回我离开这里的理由。”
```

## Suggested Godot Folder Structure

Use this structure unless the existing project already has a clear equivalent:

```text
res://
  scenes/
    main_menu/
      MainMenu.tscn
      MainMenu.gd
    shop/
      ShopScene.tscn
      ShopScene.gd
    result/
      ResultScene.tscn
      ResultScene.gd
    restock/
      RestockScene.tscn
      RestockScene.gd
    archive/
      ArchiveScene.tscn
      ArchiveScene.gd

  scripts/
    managers/
      GameManager.gd
      DataManager.gd
      SaveManager.gd
      AudioManager.gd
    systems/
      ScoreSystem.gd
      InventorySystem.gd
      ComboSystem.gd
      CustomerSystem.gd

  data/
    items.json
    customers.json
    combos.json
    nights.json
    dialogues.json

  assets/
    art/
      backgrounds/
      customers/
      items/
      ui/
    audio/
      bgm/
      sfx/

  save/
    save_data.json
```

## Script Responsibilities

### GameManager.gd

Responsible for:

- current night
- current money
- current game state
- entering shop scene
- entering result scene
- entering restock scene
- starting next night
- new game
- continue game

### DataManager.gd

Responsible for:

- loading item data
- loading customer data
- loading combo data
- loading night configuration
- providing lookup by id

### InventorySystem.gd

Responsible for:

- item stock
- buying items
- consuming items
- checking stock
- checking max stock

### CustomerSystem.gd

Responsible for:

- generating the customer queue for the current night
- switching current customer
- recording seen customers
- advancing customer story progress
- checking whether the night is complete

### ScoreSystem.gd

Responsible for:

- matching tags
- detecting avoided tags
- calculating final score
- returning grade
- returning matched tags
- returning negative tags

### ComboSystem.gd

Responsible for:

- detecting special item combinations
- returning combo name
- returning score bonus
- returning bonus tags
- returning special feedback text

### SaveManager.gd

Responsible for:

- saving game
- loading game
- creating a new save
- deleting save
- checking whether save data exists

## Development Order

Do not build art first.

Correct development order:

```text
1. Data structure
2. Item selection
3. Customer requests
4. Score feedback
5. Money and restock
6. Save system
7. Customer archive and story progress
8. Art, audio, animation, and polish
```

## First Implementation Task

If starting from scratch, the first task is:

```text
Create the Godot project skeleton.
```

Must create:

```text
1. MainMenu.tscn / MainMenu.gd
2. ShopScene.tscn / ShopScene.gd
3. ResultScene.tscn / ResultScene.gd
4. RestockScene.tscn / RestockScene.gd
5. GameManager.gd
6. DataManager.gd
7. SaveManager.gd
8. items.json
9. customers.json
10. combos.json
```

Do not make final art yet.

Use pure UI to implement the complete flow first.

Completion standard:

```text
The player can start from MainMenu, enter ShopScene, switch to ResultScene, enter RestockScene, and proceed to the next night.
```

## Testing Checklist

After each change, check:

- project opens in Godot 4.x
- main menu runs
- new game starts correctly
- continue button works or is disabled when no save exists
- shop scene loads
- customer name and dialogue display correctly
- item cards display correctly
- player can select 1–3 items
- out-of-stock items cannot be selected
- confirm button sends items to scoring
- score and grade are calculated correctly
- combo detection works
- money updates correctly
- night result screen appears after all customers
- restock screen updates money and stock correctly
- next night starts correctly
- save/load works
- no missing resources
- no script errors in the Godot output panel

## Codex Response Requirements

When modifying the project, Codex should always respond with:

1. what it inspected
2. what it changed
3. modified files
4. how to test in Godot
5. unfinished parts or risks

## Hard Constraints

Do not add unrelated game concepts.

Do not replace the fixed-screen UI MVP with a walking RPG unless explicitly requested later.

Do not create a large simulation system before the basic loop is playable.

Do not hide all item tags from code, but do not show tags directly to the player in the MVP UI unless explicitly asked. The player should infer item meaning from item names and descriptions.

Do not make failure too punishing.

Do not generate too much content at once before the systems work.

The first milestone is:

> A complete playable first night using placeholder UI.
