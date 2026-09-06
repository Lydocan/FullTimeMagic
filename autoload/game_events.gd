extends Node
## 全局事件总线（autoload：GameEvents）。
##
## 用于场景与节点之间的解耦通信：任何节点都可以发送或监听这里的信号，
## 避免节点之间直接持有引用。

## —— 探索 ↔ 战斗 ——

## 遇敌触发（enemy_ids 为数据注册表 MONSTERS 的 id 列表）。
signal encounter_started(enemy_ids: Array)

## 战斗结束（victory 是否胜利；fled 表示逃跑）。
signal battle_finished(victory: bool, fled: bool)

## 换装后广播（地图上的玩家刷新分层衣装外观）。
signal clothes_changed

## —— 成长（位阶体系）——

## 获得修为。
signal xp_gained(member_name: String, element: int, amount: int)

## 星子点亮跨过星级。
signal star_advanced(member_name: String, element: int, stage: int, star: int)

## 一系三星圆满，进入瓶颈。
signal bottleneck_reached(member_name: String, element: int)

## 突破晋升到新阶。
signal stage_advanced(member_name: String, element: int, stage: int)

## —— 资源与状态 ——

signal gold_changed(total: int)
signal essence_changed(essence_id: String, total: int)
## 队伍 HP/MP 等状态变化（HUD 刷新）。
signal party_status_changed
