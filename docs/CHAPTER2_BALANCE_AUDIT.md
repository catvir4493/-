# Chapter 2 Balance Audit

## Summary

- BLOCKER: 0
- CRITICAL: 0
- WARNING: 1

审计范围为 Chapter 2 新增的 10 个 Request，按各自首次排期夜晚的已解锁商品穷举 1–3 件合法选择。

## Request Solvability

| request_id | max_score | good_solutions | perfect_solutions | example_best | severity |
|---|---:|---:|---:|---|---|
| night_nurse_01 | 100 | 248 | 27 | coffee, mint_candy, rice_ball | OK |
| night_nurse_02 | 100 | 174 | 26 | blank_postcard, cheap_perfume, blue_pen | OK |
| night_nurse_03 | 95 | 106 | 6 | coffee, mint_candy, flashlight | OK |
| breakfast_man_01 | 95 | 332 | 17 | coffee, mint_candy, instant_noodles | OK |
| breakfast_man_02 | 100 | 528 | 65 | milk, old_photo, tissue | OK |
| breakfast_man_03 | 100 | 160 | 24 | blank_postcard, cheap_perfume, blue_pen | OK |
| student_after_exam_04 | 95 | 332 | 25 | milk, old_photo, blank_postcard | OK |
| driver_rest_04 | 95 | 189 | 22 | milk, old_photo, disposable_camera | OK |
| previous_clerk_04 | 95 | 150 | 6 | coffee, mint_candy, disposable_camera | OK |
| previous_clerk_05 | 100 | 174 | 26 | blank_postcard, cheap_perfume, blue_pen | OK |

## New Item Usage

| item_id | highest-score solution usage |
|---|---:|
| canned_peach | 2 |
| instant_noodles | 3 |
| blue_pen | 5 |
| paper_cup | 1 |

## New Combo Usage

| combo_id | highest-score solution triggers |
|---|---:|
| combo_write_it_down | 3 |
| combo_childhood_flavor | 1 |
| combo_sit_for_a_while | 0 |

## Economy and Stock Notes

- 四个新商品的 buy_price 均低于 sell_price，普通服务收入仍使用 Stage 11B 公式。
- Night 6 旧存档迁移会为缺失的新商品库存使用其 max_stock 默认值，不会形成起始软锁。
- old_photo 的 max_stock 保持 1；小时候的味道不是任何 Request 的唯一 good 解。
- 本审计允许 WARNING，但 BLOCKER 与 CRITICAL 必须为 0。
