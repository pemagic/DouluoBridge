import UIKit

class VirtualJoystick: UIView {
    
    enum Direction {
        case left, right, none
    }
    
    var onDirectionChange: ((Direction) -> Void)?
    var onDownChange: ((Bool) -> Void)?
    
    private let outerRadius: CGFloat = 70
    private let thumbRadius: CGFloat = 30
    private let deadZone: CGFloat = 15
    
    private var thumbView: UIView!
    private var centerPoint: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
    private var currentDirection: Direction = .none
    private var currentDown: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        isMultipleTouchEnabled = false
        backgroundColor = .clear
        
        // Outer ring
        let outerRing = UIView(frame: CGRect(
            x: bounds.midX - outerRadius,
            y: bounds.midY - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        ))
        outerRing.layer.cornerRadius = outerRadius
        outerRing.backgroundColor = UIColor(red: 0.4, green: 0.35, blue: 0.28, alpha: 0.12)
        outerRing.layer.borderColor = UIColor(red: 0.5, green: 0.45, blue: 0.35, alpha: 0.35).cgColor
        outerRing.layer.borderWidth = 2
        outerRing.isUserInteractionEnabled = false
        addSubview(outerRing)
        
        // Inner directional hints
        let leftArrow = createArrowLabel("◀", x: bounds.midX - outerRadius + 12, y: bounds.midY - 8)
        let rightArrow = createArrowLabel("▶", x: bounds.midX + outerRadius - 24, y: bounds.midY - 8)
        addSubview(leftArrow)
        addSubview(rightArrow)
        
        // Thumb
        thumbView = UIView(frame: CGRect(
            x: bounds.midX - thumbRadius,
            y: bounds.midY - thumbRadius,
            width: thumbRadius * 2,
            height: thumbRadius * 2
        ))
        thumbView.layer.cornerRadius = thumbRadius
        thumbView.backgroundColor = UIColor(red: 0.5, green: 0.45, blue: 0.35, alpha: 0.4)
        thumbView.layer.borderColor = UIColor(red: 0.55, green: 0.50, blue: 0.40, alpha: 0.65).cgColor
        thumbView.layer.borderWidth = 2
        thumbView.isUserInteractionEnabled = false
        
        // Shadow for thumb
        thumbView.layer.shadowColor = UIColor(red: 0.5, green: 0.45, blue: 0.35, alpha: 1.0).cgColor
        thumbView.layer.shadowRadius = 8
        thumbView.layer.shadowOpacity = 0.3
        thumbView.layer.shadowOffset = .zero
        
        addSubview(thumbView)
    }
    
    private func createArrowLabel(_ text: String, x: CGFloat, y: CGFloat) -> UILabel {
        let label = UILabel(frame: CGRect(x: x, y: y, width: 16, height: 16))
        label.text = text
        label.textColor = UIColor(red: 0.5, green: 0.45, blue: 0.35, alpha: 0.4)
        label.font = .systemFont(ofSize: 12)
        label.isUserInteractionEnabled = false
        return label
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Re-center everything when layout changes
        for subview in subviews where subview != thumbView {
            if let ring = subviews.first {
                ring.frame = CGRect(
                    x: bounds.midX - outerRadius,
                    y: bounds.midY - outerRadius,
                    width: outerRadius * 2,
                    height: outerRadius * 2
                )
            }
        }
        if currentDirection == .none {
            thumbView.center = centerPoint
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleTouch(touch)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleTouch(touch)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetThumb()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetThumb()
    }
    
    private func handleTouch(_ touch: UITouch) {
        let location = touch.location(in: self)
        let dx = location.x - centerPoint.x
        let dy = location.y - centerPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Clamp to outer radius
        let clampedDistance = min(distance, outerRadius - 5)
        let angle = atan2(dy, dx)
        
        let thumbX = centerPoint.x + cos(angle) * clampedDistance - thumbRadius
        let thumbY = centerPoint.y + sin(angle) * clampedDistance - thumbRadius
        
        thumbView.frame = CGRect(x: thumbX, y: thumbY, width: thumbRadius * 2, height: thumbRadius * 2)
        
        // Determine direction (horizontal only)
        let newDirection: Direction
        if abs(dx) < deadZone {
            newDirection = .none
        } else if dx < 0 {
            newDirection = .left
        } else {
            newDirection = .right
        }

        if newDirection != currentDirection {
            currentDirection = newDirection
            onDirectionChange?(newDirection)

            // Visual feedback
            UIView.animate(withDuration: 0.1) {
                self.thumbView.backgroundColor = newDirection == .none
                    ? UIColor(red: 0.5, green: 0.45, blue: 0.35, alpha: 0.4)
                    : UIColor(red: 0.55, green: 0.50, blue: 0.40, alpha: 0.6)
            }
        }

        // Vertical down detection (dy > 0 = down in UIKit coords)
        let isDown = dy > deadZone * 1.5
        if isDown != currentDown {
            currentDown = isDown
            onDownChange?(isDown)
        }
    }
    
    private func resetThumb() {
        currentDirection = .none
        onDirectionChange?(.none)
        if currentDown {
            currentDown = false
            onDownChange?(false)
        }
        
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
            self.thumbView.center = self.centerPoint
            self.thumbView.backgroundColor = UIColor(red: 0.5, green: 0.45, blue: 0.35, alpha: 0.4)
        }
    }
}
