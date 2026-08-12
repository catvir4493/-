# Balance Changelog

## Stage 11B

### Economy

修改前：

```text
item_sell_total + base_reward + grade_bonus
```

修改后：

```text
max(0, item_sell_total + grade_bonus)
```

原因：Stage 11A 五夜模拟经济膨胀明显，三种策略最终金钱过高。`base_reward` 字段继续保留，但暂时不参与普通服务收入。

### Item Changes

`milk`

修改前：

```text
tags = 睡眠 / 温和 / 安慰
```

修改后：

```text
tags = 睡眠 / 温和
```

原因：过高频率出现在确定性最高分解法中。

`old_photo`

修改前：

```text
buy_price = 0
tags = 回忆 / 悲伤 / 真实
max_stock = 1
```

修改后：

```text
buy_price = 2
tags = 回忆 / 悲伤
max_stock = 1
```

原因：使用率过高，同时免费补货存在经济风险。库存上限保持为 1。

### Customer Request Changes

无。

### Combo Changes

无。

### Before / After Metrics

Stage 11A：

```text
Strategy A = 970
Strategy B = 1185
Strategy C = 983

milk highest-best usage = 20 / 30
old_photo highest-best usage = 20 / 30

BLOCKER = 0
CRITICAL = 0
WARNING = 5
```

Stage 11B 当前审计实际结果：

```text
Strategy A = 545
Strategy B = 800
Strategy C = 574

milk highest-best usage = 9 / 30
old_photo highest-best usage = 9 / 30

BLOCKER = 0
CRITICAL = 0
WARNING = 3
```

以上 Stage 11B 数据由当前 Stage 12 架构上的 `tests/stage11_balance_audit.gd` 重新生成并确认。
