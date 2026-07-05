# Balance Audit

## Executive Summary

- Five-night completion: Strategy A complete, Strategy B complete, Strategy C complete.
- Blockers: 0. Critical issues: 0. Warnings: 5.
- Recommended next step: enter Stage 11B for balance tuning, with no system rewrite needed.

Most severe issues:
- WARNING `milk`: Dominant item candidate: used in 20 best solutions.
- WARNING `old_photo`: Dominant item candidate: used in 20 best solutions.
- WARNING `strategy_A_restock_pressure`: Strategy A has restock pressure: Night 1 restock could not fully pre-stock old_photo for night 2; alternate in-stock solutions may still exist., Night 2 restock could not fully pre-stock old_photo for night 3; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock old_photo for night 4; alternate in-stock solutions may still exist., Night 4 restock could not fully pre-stock old_photo for night 5; alternate in-stock solutions may still exist.
- WARNING `strategy_B_restock_pressure`: Strategy B has restock pressure: Night 1 restock could not fully pre-stock old_photo for night 2; alternate in-stock solutions may still exist., Night 2 restock could not fully pre-stock old_photo for night 3; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock old_photo for night 4; alternate in-stock solutions may still exist., Night 4 restock could not fully pre-stock old_photo for night 5; alternate in-stock solutions may still exist.
- WARNING `strategy_C_restock_pressure`: Strategy C has restock pressure: Night 1 restock could not fully pre-stock old_photo for night 2; alternate in-stock solutions may still exist., Night 2 restock could not fully pre-stock old_photo for night 3; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock old_photo for night 4; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock flashlight for night 4; alternate in-stock solutions may still exist., Night 4 restock could not fully pre-stock old_photo for night 5; alternate in-stock solutions may still exist.

## Customer Solvability

| night | request_id | customer_name | story_stage | difficulty | max_score | good_solution_count | perfect_solution_count | best_item_ids | combo_required | severity | notes |
|---:|---|---|---:|---:|---:|---:|---:|---|---|---|---|
| 1 | student_exam_01 | 黑眼圈学生 | 1 | 1 | 100 | 31 | 7 | coffee, mint_candy, rice_ball | false | INFO | - |
| 1 | overtime_worker_01 | 加班职员 | 1 | 1 | 100 | 32 | 8 | coffee, mint_candy, rice_ball | false | INFO | - |
| 1 | silent_old_man_01 | 沉默老人 | 1 | 2 | 95 | 23 | 9 | milk, mint_candy, old_photo | false | INFO | - |
| 1 | masked_boy_01 | 戴口罩的少年 | 1 | 1 | 90 | 13 | 1 | coffee, mint_candy, rice_ball | true | INFO | Good result requires a special combo. |
| 1 | insomnia_driver_01 | 失眠的司机 | 1 | 2 | 95 | 20 | 3 | bandage, coffee, mint_candy | false | INFO | - |
| 2 | wet_man_01 | 湿透的男人 | 1 | 1 | 95 | 46 | 3 | black_umbrella, coffee, mint_candy | false | INFO | - |
| 2 | red_dress_woman_01 | 穿红裙的女人 | 1 | 2 | 95 | 23 | 2 | milk, old_photo, blank_postcard | false | INFO | - |
| 2 | lost_child_01 | 迷路的小孩 | 1 | 1 | 75 | 47 | 0 | bandage, milk, old_photo | false | INFO | - |
| 2 | nameless_guest_01 | 忘记名字的客人 | 1 | 3 | 95 | 91 | 7 | milk, old_photo, blank_postcard | false | INFO | - |
| 2 | previous_clerk_hint_01 | 陌生的常客 | 1 | 2 | 95 | 91 | 7 | milk, old_photo, blank_postcard | false | INFO | - |
| 2 | student_exam_02 | 黑眼圈学生 | 2 | 2 | 95 | 41 | 3 | milk, old_photo, dark_chocolate | false | INFO | - |
| 3 | overtime_worker_02 | 加班职员 | 2 | 2 | 95 | 18 | 1 | blank_postcard, battery, flashlight | false | INFO | - |
| 3 | silent_old_man_02 | 沉默老人 | 2 | 2 | 95 | 35 | 2 | milk, old_photo, battery | false | INFO | - |
| 3 | masked_boy_02 | 戴口罩的少年 | 2 | 2 | 75 | 37 | 0 | milk, mint_candy, old_photo | false | INFO | - |
| 3 | insomnia_driver_02 | 失眠的司机 | 2 | 2 | 75 | 21 | 0 | bandage, milk, old_photo | false | INFO | - |
| 3 | wet_man_02 | 湿透的男人 | 2 | 2 | 95 | 57 | 3 | mint_candy, battery, flashlight | false | INFO | - |
| 3 | red_dress_woman_02 | 穿红裙的女人 | 2 | 2 | 95 | 63 | 4 | milk, mint_candy, old_photo | false | INFO | - |
| 3 | student_exam_03 | 黑眼圈学生 | 3 | 3 | 95 | 98 | 7 | milk, old_photo, blank_postcard | false | INFO | - |
| 4 | lost_child_02 | 迷路的小孩 | 2 | 2 | 95 | 78 | 9 | blank_postcard, battery, flashlight | false | INFO | - |
| 4 | nameless_guest_02 | 忘记名字的客人 | 2 | 3 | 95 | 91 | 5 | milk, mint_candy, old_photo | false | INFO | - |
| 4 | previous_clerk_02 | 异常的客人 | 2 | 3 | 95 | 72 | 3 | mint_candy, battery, flashlight | false | INFO | - |
| 4 | overtime_worker_03 | 加班职员 | 3 | 3 | 95 | 186 | 17 | milk, old_photo, battery | false | INFO | - |
| 4 | silent_old_man_03 | 沉默老人 | 3 | 3 | 95 | 105 | 12 | milk, old_photo, lucky_sticker | false | INFO | - |
| 4 | masked_boy_03 | 戴口罩的少年 | 3 | 3 | 95 | 221 | 21 | milk, old_photo, lucky_sticker | false | INFO | - |
| 4 | insomnia_driver_03 | 失眠的司机 | 3 | 3 | 95 | 145 | 19 | milk, old_photo, battery | false | INFO | - |
| 4 | wet_man_03 | 湿透的男人 | 3 | 3 | 95 | 102 | 7 | milk, old_photo, blank_postcard | false | INFO | - |
| 5 | red_dress_woman_03 | 穿红裙的女人 | 3 | 3 | 95 | 61 | 4 | milk, old_photo, blank_postcard | false | INFO | - |
| 5 | lost_child_03 | 迷路的小孩 | 3 | 3 | 95 | 126 | 6 | tissue, battery, flashlight | false | INFO | - |
| 5 | nameless_guest_03 | 忘记名字的客人 | 3 | 3 | 95 | 122 | 7 | milk, old_photo, blank_postcard | false | INFO | - |
| 5 | previous_clerk_01 | 上一任店员 | 3 | 3 | 95 | 102 | 8 | milk, old_photo, blank_postcard | false | INFO | - |

## Item Usage

| item_id | unlock_day | best_solution_usage | good_solution_usage | combo_count | classification | notes |
|---|---:|---:|---:|---:|---|---|
| bandage | 1 | 3 | 30 | 1 | Normal | - |
| black_umbrella | 1 | 1 | 26 | 1 | Normal | - |
| coffee | 1 | 5 | 28 | 2 | Normal | - |
| milk | 1 | 20 | 30 | 2 | Dominant Item | Appears in more than 50% of deterministic best solutions. |
| mint_candy | 1 | 11 | 29 | 1 | Normal | - |
| old_photo | 1 | 20 | 28 | 1 | Dominant Item | Appears in more than 50% of deterministic best solutions. |
| red_lighter | 1 | 0 | 20 | 1 | Normal | Frequently overlaps customer avoid tags. |
| rice_ball | 1 | 3 | 29 | 2 | Normal | - |
| sleep_mask | 1 | 0 | 13 | 0 | Normal | Frequently overlaps customer avoid tags. |
| ticket | 1 | 0 | 22 | 1 | Normal | Frequently overlaps customer avoid tags. |
| blank_postcard | 2 | 10 | 23 | 1 | Normal | - |
| dark_chocolate | 2 | 1 | 25 | 0 | Normal | - |
| disposable_camera | 2 | 0 | 23 | 0 | Normal | - |
| tissue | 2 | 1 | 25 | 1 | Normal | - |
| battery | 3 | 8 | 19 | 1 | Normal | - |
| cheap_perfume | 3 | 0 | 14 | 1 | Normal | - |
| flashlight | 3 | 5 | 19 | 1 | Normal | - |
| expired_magazine | 4 | 0 | 4 | 0 | Normal | - |
| lucky_sticker | 4 | 2 | 12 | 1 | Normal | - |
| coin | 5 | 0 | 4 | 0 | Normal | - |

## Combo Balance

| combo_id | earliest_night | suitable_customer_count | triggered_solution_count | max_score_gain | classification | notes |
|---|---:|---:|---:|---:|---|---|
| combo_after_impulse | 1 | 19 | 455 | -10 | Normal | Bonus tags overlap with: combo_find_way, combo_unsent_confession., Best score with this combo is lower than the best score without it. |
| combo_better_tomorrow | 4 | 12 | 220 | -10 | Normal | Can be part of multi-combo three-item selections; max multi-combo score 85., Bonus tags overlap with: combo_nostalgia, combo_soft_morning, combo_cry_tonight, combo_find_way., Best score with this combo is lower than the best score without it. |
| combo_cry_tonight | 2 | 25 | 410 | -10 | Normal | Can be part of multi-combo three-item selections; max multi-combo score 90., Bonus tags overlap with: combo_nostalgia, combo_better_tomorrow., Best score with this combo is lower than the best score without it. |
| combo_escape | 1 | 15 | 455 | -5 | Normal | Best score with this combo is lower than the best score without it. |
| combo_find_way | 3 | 19 | 332 | -5 | Normal | Bonus tags overlap with: combo_after_impulse, combo_soft_morning, combo_better_tomorrow., Best score with this combo is lower than the best score without it. |
| combo_nostalgia | 1 | 27 | 455 | -5 | Normal | Can be part of multi-combo three-item selections; max multi-combo score 90., Bonus tags overlap with: combo_cry_tonight, combo_better_tomorrow., Best score with this combo is lower than the best score without it. |
| combo_overtime | 1 | 26 | 455 | 5 | Normal | Can hit the score cap while non-combo solutions are already viable., Can be part of multi-combo three-item selections; max multi-combo score 100., Bonus tags overlap with: combo_soft_morning. |
| combo_soft_morning | 1 | 27 | 455 | 5 | Normal | Can hit the score cap while non-combo solutions are already viable., Can be part of multi-combo three-item selections; max multi-combo score 100., Bonus tags overlap with: combo_overtime, combo_find_way, combo_better_tomorrow. |
| combo_unsent_confession | 3 | 14 | 332 | -10 | Normal | Bonus tags overlap with: combo_after_impulse., Best score with this combo is lower than the best score without it. |

## Economy Simulation

| strategy | night | income | restock_spend | end_money | stuck | zero_stock_items |
|---|---:|---:|---:|---:|---|---|
| A - Minimum Consumption | 1 | 138 | 0 | 138 | false | old_photo |
| A - Minimum Consumption | 2 | 183 | 0 | 321 | false | old_photo |
| A - Minimum Consumption | 3 | 236 | 0 | 557 | false | old_photo, disposable_camera |
| A - Minimum Consumption | 4 | 269 | 7 | 819 | false | old_photo, flashlight, milk |
| A - Minimum Consumption | 5 | 151 | 0 | 970 | false | flashlight, old_photo, blank_postcard |
| A final |  |  |  | 970 | false | Night 1 restock could not fully pre-stock old_photo for night 2; alternate in-stock solutions may still exist., Night 2 restock could not fully pre-stock old_photo for night 3; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock old_photo for night 4; alternate in-stock solutions may still exist., Night 4 restock could not fully pre-stock old_photo for night 5; alternate in-stock solutions may still exist. |
| B - Highest Score | 1 | 175 | 0 | 175 | false | old_photo |
| B - Highest Score | 2 | 240 | 0 | 415 | false | old_photo |
| B - Highest Score | 3 | 281 | 12 | 684 | false | old_photo |
| B - Highest Score | 4 | 342 | 11 | 1015 | false | old_photo, mint_candy, flashlight, blank_postcard, disposable_camera |
| B - Highest Score | 5 | 170 | 0 | 1185 | false | old_photo, flashlight, blank_postcard, coin |
| B final |  |  |  | 1185 | false | Night 1 restock could not fully pre-stock old_photo for night 2; alternate in-stock solutions may still exist., Night 2 restock could not fully pre-stock old_photo for night 3; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock old_photo for night 4; alternate in-stock solutions may still exist., Night 4 restock could not fully pre-stock old_photo for night 5; alternate in-stock solutions may still exist. |
| C - Combo First | 1 | 146 | 0 | 146 | false | old_photo |
| C - Combo First | 2 | 207 | 6 | 347 | false | old_photo |
| C - Combo First | 3 | 230 | 19 | 558 | false | old_photo |
| C - Combo First | 4 | 284 | 14 | 828 | false | old_photo, flashlight, milk |
| C - Combo First | 5 | 155 | 0 | 983 | false | old_photo, coin, flashlight |
| C final |  |  |  | 983 | false | Night 1 restock could not fully pre-stock old_photo for night 2; alternate in-stock solutions may still exist., Night 2 restock could not fully pre-stock old_photo for night 3; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock old_photo for night 4; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock flashlight for night 4; alternate in-stock solutions may still exist., Night 4 restock could not fully pre-stock old_photo for night 5; alternate in-stock solutions may still exist. |

## Unlock Progression

| night | newly_unlocked_item_ids | unlocked_item_ids | available_combo_ids | customer_count | solvable_customer_count | critical_customer_ids |
|---:|---|---|---|---:|---:|---|
| 1 | bandage, black_umbrella, coffee, milk, mint_candy, old_photo, red_lighter, rice_ball, sleep_mask, ticket | bandage, black_umbrella, coffee, milk, mint_candy, old_photo, red_lighter, rice_ball, sleep_mask, ticket | combo_overtime, combo_nostalgia, combo_escape, combo_after_impulse, combo_soft_morning | 5 | 5 | - |
| 2 | blank_postcard, dark_chocolate, disposable_camera, tissue | bandage, black_umbrella, coffee, milk, mint_candy, old_photo, red_lighter, rice_ball, sleep_mask, ticket, blank_postcard, dark_chocolate, disposable_camera, tissue | combo_overtime, combo_nostalgia, combo_escape, combo_after_impulse, combo_soft_morning, combo_cry_tonight | 6 | 6 | - |
| 3 | battery, cheap_perfume, flashlight | bandage, black_umbrella, coffee, milk, mint_candy, old_photo, red_lighter, rice_ball, sleep_mask, ticket, blank_postcard, dark_chocolate, disposable_camera, tissue, battery, cheap_perfume, flashlight | combo_overtime, combo_nostalgia, combo_escape, combo_after_impulse, combo_soft_morning, combo_cry_tonight, combo_find_way, combo_unsent_confession | 7 | 7 | - |
| 4 | expired_magazine, lucky_sticker | bandage, black_umbrella, coffee, milk, mint_candy, old_photo, red_lighter, rice_ball, sleep_mask, ticket, blank_postcard, dark_chocolate, disposable_camera, tissue, battery, cheap_perfume, flashlight, expired_magazine, lucky_sticker | combo_overtime, combo_nostalgia, combo_escape, combo_after_impulse, combo_soft_morning, combo_cry_tonight, combo_find_way, combo_unsent_confession, combo_better_tomorrow | 8 | 8 | - |
| 5 | coin | bandage, black_umbrella, coffee, milk, mint_candy, old_photo, red_lighter, rice_ball, sleep_mask, ticket, blank_postcard, dark_chocolate, disposable_camera, tissue, battery, cheap_perfume, flashlight, expired_magazine, lucky_sticker, coin | combo_overtime, combo_nostalgia, combo_escape, combo_after_impulse, combo_soft_morning, combo_cry_tonight, combo_find_way, combo_unsent_confession, combo_better_tomorrow | 4 | 4 | - |

## Difficulty Curve

| night | customer_count | average_difficulty | average_max_score | average_good_solutions | average_perfect_solutions | theoretical_rating | risk |
|---:|---:|---:|---:|---:|---:|---|---|
| 1 | 5 | 1.40 | 96.00 | 23.80 | 5.60 | S | - |
| 2 | 6 | 1.83 | 91.67 | 56.50 | 3.67 | S | - |
| 3 | 7 | 2.14 | 89.29 | 47.00 | 2.43 | A | - |
| 4 | 8 | 2.88 | 95.00 | 125.00 | 11.63 | S | - |
| 5 | 4 | 3.00 | 95.00 | 102.75 | 6.25 | S | - |

## Findings by Severity

### BLOCKER
- None.

### CRITICAL
- None.

### WARNING
- `milk` (data/items.json): Dominant item candidate: used in 20 best solutions.
- `old_photo` (data/items.json): Dominant item candidate: used in 20 best solutions.
- `strategy_A_restock_pressure` (data/items.json): Strategy A has restock pressure: Night 1 restock could not fully pre-stock old_photo for night 2; alternate in-stock solutions may still exist., Night 2 restock could not fully pre-stock old_photo for night 3; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock old_photo for night 4; alternate in-stock solutions may still exist., Night 4 restock could not fully pre-stock old_photo for night 5; alternate in-stock solutions may still exist.
- `strategy_B_restock_pressure` (data/items.json): Strategy B has restock pressure: Night 1 restock could not fully pre-stock old_photo for night 2; alternate in-stock solutions may still exist., Night 2 restock could not fully pre-stock old_photo for night 3; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock old_photo for night 4; alternate in-stock solutions may still exist., Night 4 restock could not fully pre-stock old_photo for night 5; alternate in-stock solutions may still exist.
- `strategy_C_restock_pressure` (data/items.json): Strategy C has restock pressure: Night 1 restock could not fully pre-stock old_photo for night 2; alternate in-stock solutions may still exist., Night 2 restock could not fully pre-stock old_photo for night 3; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock old_photo for night 4; alternate in-stock solutions may still exist., Night 3 restock could not fully pre-stock flashlight for night 4; alternate in-stock solutions may still exist., Night 4 restock could not fully pre-stock old_photo for night 5; alternate in-stock solutions may still exist.

### INFO
- `student_exam_01` (data/customers.json): Multiple reasonable solutions are available.
- `overtime_worker_01` (data/customers.json): Multiple reasonable solutions are available.
- `silent_old_man_01` (data/customers.json): Multiple reasonable solutions are available.
- `masked_boy_01` (data/customers.json): Multiple reasonable solutions are available.
- `insomnia_driver_01` (data/customers.json): Multiple reasonable solutions are available.
- `wet_man_01` (data/customers.json): Multiple reasonable solutions are available.
- `red_dress_woman_01` (data/customers.json): Multiple reasonable solutions are available.
- `lost_child_01` (data/customers.json): Multiple reasonable solutions are available.
- `nameless_guest_01` (data/customers.json): Multiple reasonable solutions are available.
- `previous_clerk_hint_01` (data/customers.json): Multiple reasonable solutions are available.
- `student_exam_02` (data/customers.json): Multiple reasonable solutions are available.
- `overtime_worker_02` (data/customers.json): Multiple reasonable solutions are available.
- `silent_old_man_02` (data/customers.json): Multiple reasonable solutions are available.
- `masked_boy_02` (data/customers.json): Multiple reasonable solutions are available.
- `insomnia_driver_02` (data/customers.json): Multiple reasonable solutions are available.
- `wet_man_02` (data/customers.json): Multiple reasonable solutions are available.
- `red_dress_woman_02` (data/customers.json): Multiple reasonable solutions are available.
- `student_exam_03` (data/customers.json): Multiple reasonable solutions are available.
- `lost_child_02` (data/customers.json): Multiple reasonable solutions are available.
- `nameless_guest_02` (data/customers.json): Multiple reasonable solutions are available.
- `previous_clerk_02` (data/customers.json): Multiple reasonable solutions are available.
- `overtime_worker_03` (data/customers.json): Multiple reasonable solutions are available.
- `silent_old_man_03` (data/customers.json): Multiple reasonable solutions are available.
- `masked_boy_03` (data/customers.json): Multiple reasonable solutions are available.
- `insomnia_driver_03` (data/customers.json): Multiple reasonable solutions are available.
- `wet_man_03` (data/customers.json): Multiple reasonable solutions are available.
- `red_dress_woman_03` (data/customers.json): Multiple reasonable solutions are available.
- `lost_child_03` (data/customers.json): Multiple reasonable solutions are available.
- `nameless_guest_03` (data/customers.json): Multiple reasonable solutions are available.
- `previous_clerk_01` (data/customers.json): Multiple reasonable solutions are available.

## Recommended Stage 11B Changes

1. Must fix
- None currently required.

2. Should adjust
- `milk` in `data/items.json`: Dominant Item. Recommended adjustment: review tags, price, unlock day, or combo support in Stage 11B. Expected impact: broader viable choices. Risk: can disturb current good solutions.
- `old_photo` in `data/items.json`: Dominant Item. Recommended adjustment: review tags, price, unlock day, or combo support in Stage 11B. Expected impact: broader viable choices. Risk: can disturb current good solutions.

3. Optional optimization
- `tests/stage11_balance_audit.gd`: keep this audit as a regression check before future content tuning. Expected impact: catches unlock, score, and economy regressions early. Risk: report thresholds may need tuning as design goals mature.
