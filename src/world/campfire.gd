extends Area2D
## 营地篝火交互点：靠近按 E 打开休息/修炼/突破/存档菜单。

signal camp_used


func interact() -> void:
	camp_used.emit()
