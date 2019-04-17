//
//  JLXXNavBarTransparent.swift
//  JinglanEx
//
//  Created by apple on 2017/3/1.
//  Copyright © 2017年 apple. All rights reserved.
//

import UIKit

extension DispatchQueue {
	
	private static var onceTracker = [String]()
	
	public class func once(token: String, block: () -> Void) {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }
		
		if onceTracker.contains(token) {
			return
		}
		
		onceTracker.append(token)
		block()
	}
}

extension UIViewController {
	
	private struct AssociatedKeys {
		static var navBarBgAlpha: CGFloat = 1.0
		static var navBarColor: CGFloat = 2.0
	}
	
	public var navBarAlpha: CGFloat {
		get {
			guard let alpha = objc_getAssociatedObject(self, &AssociatedKeys.navBarBgAlpha) as? CGFloat else {
				return 1.0
			}
			return alpha
			
		}
		set {
			let alpha = max(min(newValue, 1), 0) // 必须在 0~1的范围
			objc_setAssociatedObject(self, &AssociatedKeys.navBarBgAlpha, alpha, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			// Update UI
			navigationController?.needsChangeBackgroundAlpha(alpha: alpha)
			navigationController?.needsChangeShadow()
		}
	}
	public var navBarColor: UIColor {
		get {
			if let color = objc_getAssociatedObject(self, &AssociatedKeys.navBarColor) as? UIColor {
				return color
			}
			let color = UIColor.white
			objc_setAssociatedObject(self, &AssociatedKeys.navBarColor, color, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			return color
		}
		set {
			objc_setAssociatedObject(self, &AssociatedKeys.navBarColor, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			// Update UI
			navigationController?.needsChangeBackgroundColor(color: newValue)
			navigationController?.needsChangeShadow()
		}
	}
	
	//    open var navBarTintColor: UIColor {
	//        get {
	//            guard let tintColor = objc_getAssociatedObject(self, &AssociatedKeys.navBarTintColor) as? UIColor else {
	//                return UIColor.defaultNavBarTintColor
	//            }
	//            return tintColor
	//
	//        }
	//        set {
	//            navigationController?.navigationBar.tintColor = newValue
	//            objc_setAssociatedObject(self, &AssociatedKeys.navBarTintColor, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
	//        }
	//    }
}

extension UINavigationController {
	
	override open var preferredStatusBarStyle: UIStatusBarStyle {
		return topViewController?.preferredStatusBarStyle ?? .default
	}
	
	open override func viewDidLoad() {
		UINavigationController.swizzle()
		super.viewDidLoad()
		
	}
	
	private static let onceToken = UUID().uuidString
	
	class func swizzle() {
		guard self == UINavigationController.self else { return }
		
		DispatchQueue.once(token: onceToken) {
			let needSwizzleSelectorArr = [
				NSSelectorFromString("_updateInteractiveTransition:"),
				#selector(popToViewController),
				#selector(popToRootViewController)
			]
			
			for selector in needSwizzleSelectorArr {
				
				let str = ("et_" + selector.description).replacingOccurrences(of: "__", with: "_")
				// popToRootViewControllerAnimated: et_popToRootViewControllerAnimated:
				
				let originalMethod = class_getInstanceMethod(self, selector)
				let swizzledMethod = class_getInstanceMethod(self, Selector(str))
				if originalMethod != nil && swizzledMethod != nil {
					method_exchangeImplementations(originalMethod!, swizzledMethod!)
				}
			}
		}
	}
	
	@objc func et_updateInteractiveTransition(_ percentComplete: CGFloat) {
		
		guard let topViewController = topViewController, let coordinator = topViewController.transitionCoordinator else {
			et_updateInteractiveTransition(percentComplete)
			return
		}
		let fromViewController = coordinator.viewController(forKey: .from)
		let toViewController = coordinator.viewController(forKey: .to)
		
		needsChangeShadow()
		
		// Bg Alpha
		let fromAlpha = fromViewController?.navBarAlpha ?? 0
		let toAlpha = toViewController?.navBarAlpha ?? 0
		let newAlpha = fromAlpha + (toAlpha - fromAlpha) * percentComplete
		needsChangeBackgroundAlpha(alpha: newAlpha)
		
		//barView Color
		let fromColor = fromViewController?.navBarColor
		let toColor = toViewController?.navBarColor
		let newColor = averageColor(fromColor: fromColor, toColor: toColor, percent: percentComplete)
		needsChangeBackgroundColor(color: newColor)
		
		// Tint Color
		//        let fromColor = fromViewController?.navBarTintColor ?? .blue
		//        let toColor = toViewController?.navBarTintColor ?? .blue
		//        let newColor = averageColor(fromColor: fromColor, toColor: toColor, percent: percentComplete)
		//        navigationBar.tintColor = newColor
		et_updateInteractiveTransition(percentComplete)
	}
	
	// Calculate the middle Color with translation percent
	private func averageColor(fromColor: UIColor?, toColor: UIColor?, percent: CGFloat) -> UIColor {
		var fromRed: CGFloat = 0
		var fromGreen: CGFloat = 0
		var fromBlue: CGFloat = 0
		var fromAlpha: CGFloat = 0
		fromColor?.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
		
		var toRed: CGFloat = 0
		var toGreen: CGFloat = 0
		var toBlue: CGFloat = 0
		var toAlpha: CGFloat = 0
		toColor?.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)
		
		let nowRed = fromRed + (toRed - fromRed) * percent
		let nowGreen = fromGreen + (toGreen - fromGreen) * percent
		let nowBlue = fromBlue + (toBlue - fromBlue) * percent
		let nowAlpha = fromAlpha + (toAlpha - fromAlpha) * percent
		
		return UIColor(red: nowRed, green: nowGreen, blue: nowBlue, alpha: nowAlpha)
	}
	
	@objc func et_popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
		needsChangeShadow()
		needsChangeBackgroundAlpha(alpha: viewController.navBarAlpha)
		needsChangeBackgroundColor(color: viewController.navBarColor)
		//        navigationBar.tintColor = viewController.navBarTintColor
		return et_popToViewController(viewController, animated: animated)
	}
	
	@objc func et_popToRootViewControllerAnimated(_ animated: Bool) -> [UIViewController]? {
		if let firstController = viewControllers.first {
			needsChangeShadow()
			needsChangeBackgroundAlpha(alpha: firstController.navBarAlpha)
			needsChangeBackgroundColor(color: firstController.navBarColor)
		}
		//        navigationBar.tintColor = viewControllers.first?.navBarTintColor
		return et_popToRootViewControllerAnimated(animated)
	}
	
	fileprivate func needsChangeBackgroundAlpha(alpha: CGFloat) {
		navigationBar.jlxxBar.alpha = alpha
	}
	
	fileprivate func needsChangeBackgroundColor(color: UIColor?) {
		navigationBar.jlxxBar.backgroundColor = color
	}
	
	fileprivate func needsChangeShadow() {
		//		navigationBar.jlxxBar.shadow()
	}
	
}

extension UINavigationController: UINavigationBarDelegate {
	
	public func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
		
		if let topVC = topViewController, let coor = topVC.transitionCoordinator, coor.initiallyInteractive {//在有动画的时候,再监听手势动作是否中断了
			if #available(iOS 10.0, *) {
				coor.notifyWhenInteractionChanges({ (context) in
					self.dealInteractionChanges(context)
				})
			} else {
				coor.notifyWhenInteractionEnds({ (context) in
					self.dealInteractionChanges(context)
				})
			}
			return true
		}
		
		let itemCount = navigationBar.items?.count ?? 0
		let n = viewControllers.count >= itemCount ? 2 : 1
		
		let popToVC = viewControllers[viewControllers.count - n]
		
		popToViewController(popToVC, animated: true)
		return true
	}
	
	public func navigationBar(_ navigationBar: UINavigationBar, shouldPush item: UINavigationItem) -> Bool {
		needsChangeShadow()
		needsChangeBackgroundAlpha(alpha: topViewController?.navBarAlpha ?? 0)
		needsChangeBackgroundColor(color: topViewController?.navBarColor)
		return true
	}
	
	//解决自定义返回按钮后,在是首页进行滑动返回操作,导致下一次push时app假死
	public func navigationBar(_ navigationBar: UINavigationBar, didPush item: UINavigationItem) {
		if viewControllers.count > 1 {
			interactivePopGestureRecognizer?.isEnabled = true
		}
	}
	
	public func navigationBar(_ navigationBar: UINavigationBar, didPop item: UINavigationItem) {
		if viewControllers.count == 1 {
			interactivePopGestureRecognizer?.isEnabled = false
		}
	}
	
	private func dealInteractionChanges(_ context: UIViewControllerTransitionCoordinatorContext) {
		let animations: (UITransitionContextViewControllerKey) -> () = {
			let nowAlpha = context.viewController(forKey: $0)?.navBarAlpha ?? 0
			self.needsChangeShadow()
			self.needsChangeBackgroundAlpha(alpha: nowAlpha)
			self.needsChangeBackgroundColor(color: context.viewController(forKey: $0)?.navBarColor)
		}
		
		if context.isCancelled {
			let cancelDuration: TimeInterval = context.transitionDuration * Double(context.percentComplete)
			UIView.animate(withDuration: cancelDuration) {
				animations(.from)
			}
		} else {
			let finishDuration: TimeInterval = context.transitionDuration * Double(1 - context.percentComplete)
			UIView.animate(withDuration: finishDuration) {
				animations(.to)
			}
		}
	}
}


extension UINavigationBar {
	
	private struct AssociatedKeys {
		static var barView: CGFloat = 3.0
	}
	
	fileprivate var jlxxBar: JLXXNavBar {
		get {
			if let jlxxBar = objc_getAssociatedObject(self, &AssociatedKeys.barView) as? JLXXNavBar {
				return jlxxBar
			}
			
			let jlxxBar = JLXXNavBar(navigationBar: self)
			objc_setAssociatedObject(self, &AssociatedKeys.barView, jlxxBar, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			return jlxxBar
		}
	}
	
}

private class JLXXNavBar {
	
	private var statusBarView: UIView?
	private var navBarView: UIView
	
	fileprivate var alpha: CGFloat {
		get {
			return navBarView.alpha
		}
		set {
			navBarView.alpha = newValue
		}
	}
	
	fileprivate var backgroundColor: UIColor? {
		get {
			return navBarView.backgroundColor
		}
		set {
			navBarView.backgroundColor = newValue
		}
	}
	
	fileprivate init(navigationBar: UINavigationBar) {
		
		navigationBar.setBackgroundImage(UIImage(), for: .default)
		navigationBar.shadowImage = UIImage()
		
		let statusBarHeight = UIApplication.shared.statusBarFrame.height
		let width = navigationBar.bounds.width
		let height = navigationBar.bounds.height
		let frame = CGRect(x: 0, y: -statusBarHeight, width: width, height: height + statusBarHeight)
		let navBarView = UIView(frame: frame)
		navBarView.isUserInteractionEnabled = false
		navBarView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		navigationBar.insertSubview(navBarView, at: 0)
		//iOS系统不同版本布局问题,有的系统会把它放在navigationBar的最上边,所以这里设置一下zPosition
		navBarView.layer.zPosition = -1.0
		self.navBarView = navBarView
		
	}
	
}

