class_name LoadingPckLoadedEvent extends GameEvent

## loading.pck 加载完成事件
##
## 当 loading.pck 加载完成（成功或失败）时触发。
## loading.tscn 场景应监听此事件来决定何时显示 UI。
##
## Properties:
## - success: 是否成功加载 loading.pck

## 是否成功加载
var success: bool = true

