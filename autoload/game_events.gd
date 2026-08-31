extends Node
## 全局事件总线（autoload：GameEvents）。
##
## 用于场景与节点之间的解耦通信：任何节点都可以发送或监听这里的信号，
## 避免节点之间直接持有引用。按需在这里补充全局级信号。


## 玩家生命值变化（当前值, 最大值）。
signal player_health_changed(current: int, max_health: int)

## 玩家拾取物品（物品 ID）。
signal item_picked_up(item_id: String)

## 玩家金币数量变化（当前总金币）。
signal gold_changed(total: int)

## 请求打开某个界面（界面名，如 "inventory"、"pause_menu"）。
signal ui_open_requested(ui_name: String)

## 请求切换场景（目标场景路径）。
signal scene_change_requested(scene_path: String)
