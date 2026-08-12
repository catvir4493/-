# Chapter 2

## Theme

第二章：那些没说出口的话（Words Left Unsaid）。

本章围绕迟到的道歉、没有寄出的告别、犹豫是否离开，以及“如果当时说出来会不会不一样”。氛围继续保持安静、温暖、微妙诡异与孤独但不绝望。

## Nights

- Night 6「重新见面」：夜班护士 1、早餐男人 1、学生 4、加班职员 1、司机 1。
- Night 7「有些话先别说」：上一任店员 4、夜班护士 1、早餐男人 1、加班职员 1、司机 1。
- Night 8「写下来」：夜班护士 2、夜班护士 1、早餐男人 1、加班职员 1、司机 1。
- Night 9「以前喜欢的东西」：早餐男人 2、司机 4、夜班护士 1、加班职员 1、司机 1。
- Night 10「说不说都要继续生活」：夜班护士 3、早餐男人 3、加班职员 1、司机 1、上一任店员 5。

Night 6–10 使用固定顺序。重复出现的槽位只引用 `repeatable=true` 的请求，不引入随机系统。

## New Customers

### night_nurse_story

夜班护士长期替别人处理痛苦，却不敢告诉家人自己已经快撑不住。她在 Chapter 2 经历拖延回家、写下未必寄出的信，以及递交辞职申请后的动摇。

### divorced_father_story

公开身份始终是“来买早餐的男人”。他与一个很久没见的人重新约早餐，记得对方小时候喜欢甜食，并开始考虑一次迟到了很多年的道歉。本章不完全解决这条故事线。

## Returning Customers

- `student_story` Stage 4：考试结束后的失重感。
- `driver_story` Stage 4：决定停跑一晚，却不知道回家后该做什么。
- `previous_clerk_story` Stage 4：询问玩家是否开始习惯这里。
- `previous_clerk_story` Stage 5：谈论说出口与保持沉默都无法让问题自动消失。

## New Items

- `canned_peach`：黄桃罐头，Night 6 解锁。
- `instant_noodles`：桶装泡面，Night 6 解锁。
- `blue_pen`：蓝色圆珠笔，Night 7 解锁。
- `paper_cup`：纸杯，Night 8 解锁。

所有商品只使用既有合法标签，没有扩充标签池。

## New Combos

- `blue_pen + blank_postcard`：终于写下来了。
- `canned_peach + old_photo`：小时候的味道。
- `instant_noodles + paper_cup`：先坐一会儿。

## Story Events

- `event_ch2_begin`：进入 Night 6。
- `event_nurse_resignation`：夜班护士 Stage 3 服务完成。
- `event_breakfast_apology`：早餐男人 Stage 3 服务完成。
- `event_ch2_complete`：Night 10 结算并完成 Chapter 2。

事件继续只负责检测、记录和日志，不自动播放 CG。

## Chapter Ending State

Night 10 完成后记录 `chapter_02` completed。Chapter 2 不是游戏最终结局，不新增正式 Ending；Chapter 1 的 `ending_mvp_placeholder` 原样保留。

## Hooks for Chapter 3

- previous_clerk 仍未解释自己留下了什么，以及交接是否真的完成。
- nurse 需要面对辞职之后的生活与家人。
- breakfast man 的道歉和早餐结果仍未揭示。

以上只是设计钩子，本阶段没有开发 Chapter 3 正式内容。
