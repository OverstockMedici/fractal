//
//  Button.swift
//  Mercari
//
//  Created by Anthony Smith on 31/10/2017.
//  Copyright © 2017 Mercari, Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIControl.State: Hashable {
    public var hashValue: Int {
        return Int(rawValue)
    }
}

public protocol ButtonBrand {
    func typography(for size: Button.Size) -> Typography
    func widthPadding(for size: Button.Size) -> CGFloat
    func contentInset(for size: Button.Size) -> UIEdgeInsets
    func height(for size: Button.Size) -> CGFloat
    func configure(_ button: Button, with style: Button.Style)
}

private class ButtonLayer: CAGradientLayer {

    var borderColors: [UIControl.State: CGColor] = [:]
    var gradientColors: [UIControl.State: [CGColor]] = [:]

    override var borderColor: CGColor? { didSet { borderColors[.normal] = borderColor } }
    override var colors: [Any]? { didSet { gradientColors[.normal] = colors as? [CGColor] } }

    func updateColors(for state: UIControl.State) {
        super.borderColor = borderColors[state] ?? borderColors[.normal]
        super.colors = gradientColors[state] ?? gradientColors[.normal]
    }
}

final public class Button: UIButton {
    
    public struct Style: Equatable, RawRepresentable {
        public let rawValue: String
        
        public init(_ value: String) {
            self.rawValue = value
        }
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        public static func ==(lhs: Style, rhs: Style) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }
    }
    
    public struct Size {
        
        public let width: Width
        public let height: Height
        
        public init(width: Width, height: Height) {
            self.width = width
            self.height = height
        }
        
        public enum Width {
            case full, half, natural, custom(CGFloat)
            
            public var rawValue: String {
                switch self {
                case .full:
                    return "full"
                case .half:
                    return "half"
                case .natural:
                    return "natural"
                case .custom(let constant):
                    return "custom_\(constant)"
                }
            }
        }
        
        public enum Height {
            case small, medium, large, natural, custom(CGFloat)
            
            public var rawValue: String {
                switch self {
                case .small:
                    return "small"
                case .medium:
                    return "medium"
                case .large:
                    return "large"
                case .natural:
                    return "natural"
                case .custom(let constant):
                    return "custom_\(constant)"
                }
            }
        }
    }
    
    public let style: Style
    public let size: Size
    
    private var backgroundColors: [UIControl.State: UIColor] = [:]
    private var designChangeNotificationObject: NSObjectProtocol?
    private var rerenderNotificationObject: NSObjectProtocol?

    override public var backgroundColor: UIColor? { didSet { backgroundColors[.normal] = backgroundColor } }
    override public var isSelected: Bool { didSet { updateBackground() } }
    override public var isHighlighted: Bool { didSet { updateBackground() } }
    override public var isEnabled: Bool { didSet { updateBackground() } }

    override public class var layerClass: AnyClass {
        return ButtonLayer.self
    }

    private var buttonLayer: ButtonLayer? {
        return layer as? ButtonLayer
    }

    var gradientLayer: CAGradientLayer? {
        return layer as? CAGradientLayer
    }

    public init(style: Style, size: Size) {
        self.size = size
        self.style = style
        super.init(frame: .zero)
        setup()
    }
    
    public init(_ style: Style, _ size: Size) {
        self.size = size
        self.style = style
        super.init(frame: .zero)
        setup()
    }
    
    public init(_ style: Style, _ sizeTuple: (width: Size.Width, height: Size.Height)) {
        self.size = Size(width: sizeTuple.width, height: sizeTuple.height)
        self.style = style
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        designChangeNotificationObject = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: BrandingManager.didChangeNotification), object: nil, queue: nil) { [weak self] (_) in
            self?.setForBrand()
        }
        
        rerenderNotificationObject = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: BrandingManager.buttonsRerenderNotification), object: nil, queue: nil) { [weak self] (_) in
            self?.setForBrand()
        }
        
        setForBrand()
    }
    
    deinit {
        if let observer = designChangeNotificationObject {
            NotificationCenter.default.removeObserver(observer)
        }

        if let observer = rerenderNotificationObject {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setForBrand() {
        if let buttonBrand = BrandingManager.brand as? ButtonBrand {
            contentEdgeInsets = buttonBrand.contentInset(for: size)
            titleLabel?.font = buttonBrand.typography(for: size).font
            buttonBrand.configure(self, with: style)
        } else {
            print("BrandingManager.brand does not conform to protocol ButtonBrand")
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @discardableResult public func pin(sizeIn view: UIView) -> [NSLayoutConstraint] {
        pin(to: view, [.width(for: size, brand: BrandingManager.brand as? ButtonBrand),
                       .height(for: size, brand: BrandingManager.brand as? ButtonBrand)])
    }
    
    public func setBackgroundColor(_ color: UIColor?, for state: UIControl.State) {
        backgroundColors[state] = color
        updateBackground()
    }

    public func setBorderColor(_ color: UIColor?, for state: UIControl.State) {
        buttonLayer?.borderColors[state] = color?.cgColor
        updateBackground()
    }

    public func setGradientColors(_ colors: [UIColor]?, for state: UIControl.State) {
        buttonLayer?.gradientColors[state] = colors?.map { $0.cgColor }
        updateBackground()
    }

    public func resetColors() {
        backgroundColors = [:]
        buttonLayer?.borderColors = [:]
        buttonLayer?.gradientColors = [:]
        updateBackground()
    }

    private func updateBackground() {
        let backgroundColor = backgroundColors[state] ?? alternativeBackgroundColor
        super.backgroundColor = backgroundColor

        buttonLayer?.updateColors(for: state)
    }

    private var alternativeBackgroundColor: UIColor? {
        let normal = backgroundColors[.normal]
        let selected = backgroundColors[.selected] ?? backgroundColors[.normal]

        switch state {
        case .highlighted, .selected, [.selected, .highlighted]:
            return normal?.darker()
        case .disabled:
            return normal?.alpha()
        case [.selected, .disabled]:
            return selected?.lighter()
        default:
            return normal
        }
    }
}

extension Pin {

    static func width(for size: Button.Size, brand: ButtonBrand? = nil) -> Pin {
        switch size.width {
        case .custom(let value):
            return .width(asConstant: value)
        case .full:
            return .width(brand?.widthPadding(for: size) ?? -.keyline*2)
        case .half:
            return .width(options: [.multiplier(0.5)])
        case .natural:
            return .none
        }
    }
    
    static func height(for size: Button.Size, brand: ButtonBrand? = nil) -> Pin {
        
        func defaultPin() -> Pin {
            switch size.height {
            case .natural:
                return .none
            case .small:
                return .height(asConstant: 32.0)
            case .medium:
                return .height(asConstant: 44.0)
            case .large:
                return .height(asConstant: 52.0)
            case .custom(let value):
                return .height(asConstant: value)
            }
        }
        
        if let brand = brand {
            let floatValue = brand.height(for: size)
            return floatValue == 0.0 ? .none : .height(asConstant: floatValue)
        }
        
        if let brand = BrandingManager.brand as? ButtonBrand {
            let floatValue = brand.height(for: size)
            return floatValue == 0.0 ? .none : .height(asConstant: floatValue)
        }
        
        return defaultPin()

    }
}
