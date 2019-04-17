# JLXXNavBarTransparent

## 修改自[ETNavBarTransparent](https://github.com/EnderTan/ETNavBarTransparent)

### 修复不同系统导航UI布局问题,有的系统会把它放在navigationBar的最上边的bug,设置一下zPosition
```swift
	navBarView.layer.zPosition = -1.0
```
### 修改设置颜色的方法
```swift
	navBarAlpha = 0.0
	navBarColor = .white
```
