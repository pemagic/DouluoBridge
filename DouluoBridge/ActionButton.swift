import UIKit

class ActionButton: UIView {
    
    var onKeyEvent: ((String, Bool) -> Void)?
    
    private let keyCode: String
    private let holdable: Bool
    private let accentColor: UIColor
    
    private var isPressed = false
    private var holdTimer: Timer?
    
    private let emojiLabel = UILabel()
    private let textLabel = UILabel()
    private let glowLayer = CALayer()
    
    // Cooldown overlay
    private let cooldownOverlay = UIView()
    private let cooldownLabel = UILabel()
    private var cooldownHeightConstraint: NSLayoutConstraint?
    
    init(label: String, sublabel: String, color: UIColor, keyCode: String, holdable: Bool) {
        self.keyCode = keyCode
        self.holdable = holdable
        self.accentColor = color
        super.init(frame: .zero)
        
        setupView(label: label, sublabel: sublabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView(label: String, sublabel: String) {
        isMultipleTouchEnabled = false
        clipsToBounds = true
        
        // Ink wash rice paper background
        backgroundColor = UIColor(red: 0.88, green: 0.84, blue: 0.78, alpha: 0.25)
        layer.cornerRadius = 18
        layer.borderColor = UIColor(red: 0.35, green: 0.30, blue: 0.22, alpha: 0.6).cgColor
        layer.borderWidth = 2.5
        
        // Ink shadow (brush stroke feel)
        layer.shadowColor = UIColor(red: 0.2, green: 0.18, blue: 0.12, alpha: 1.0).cgColor
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 1, height: 2)
        
        // Glow layer for press feedback
        glowLayer.shadowColor = accentColor.cgColor
        glowLayer.shadowRadius = 10
        glowLayer.shadowOpacity = 0
        glowLayer.shadowOffset = .zero
        layer.addSublayer(glowLayer)
        
        // Cooldown overlay (dark gradient from top, height = ratio of cooldown)
        cooldownOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        cooldownOverlay.isUserInteractionEnabled = false
        cooldownOverlay.isHidden = true
        addSubview(cooldownOverlay)
        cooldownOverlay.translatesAutoresizingMaskIntoConstraints = false
        let hc = cooldownOverlay.heightAnchor.constraint(equalToConstant: 0)
        cooldownHeightConstraint = hc
        NSLayoutConstraint.activate([
            cooldownOverlay.topAnchor.constraint(equalTo: topAnchor),
            cooldownOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            cooldownOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            hc
        ])
        
        // Cooldown time label
        cooldownLabel.text = ""
        cooldownLabel.font = .boldSystemFont(ofSize: 10)
        cooldownLabel.textColor = .white
        cooldownLabel.textAlignment = .center
        cooldownLabel.isUserInteractionEnabled = false
        cooldownLabel.isHidden = true
        addSubview(cooldownLabel)
        cooldownLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cooldownLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            cooldownLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
        
        // Label (emoji or character)
        emojiLabel.text = label
        emojiLabel.font = .systemFont(ofSize: 28)
        emojiLabel.textAlignment = .center
        emojiLabel.isUserInteractionEnabled = false
        addSubview(emojiLabel)
        
        // Calligraphy sub-label
        textLabel.text = sublabel
        textLabel.font = UIFont(name: "PingFangSC-Semibold", size: 13) ?? .boldSystemFont(ofSize: 13)
        textLabel.textColor = UIColor(red: 0.30, green: 0.25, blue: 0.18, alpha: 0.85)
        textLabel.textAlignment = .center
        textLabel.isUserInteractionEnabled = false
        addSubview(textLabel)
        
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emojiLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6),
            textLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            textLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: -2),
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        glowLayer.frame = bounds
    }
    
    // MARK: - Cooldown API
    
    /// Update cooldown display. ratio: 0.0 = ready, 1.0 = full cooldown
    func setCooldown(ratio: CGFloat, seconds: Double) {
        let clamped = max(0, min(1, ratio))
        if clamped <= 0 {
            cooldownOverlay.isHidden = true
            cooldownLabel.isHidden = true
            layer.borderColor = UIColor(red: 0.35, green: 0.30, blue: 0.22, alpha: 0.6).cgColor
        } else {
            cooldownOverlay.isHidden = false
            cooldownLabel.isHidden = false
            cooldownHeightConstraint?.constant = bounds.height * clamped
            cooldownLabel.text = String(format: "%.1fs", seconds)
            layer.borderColor = UIColor(red: 0.2, green: 0.18, blue: 0.15, alpha: 0.3).cgColor
        }
        layoutIfNeeded()
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        pressDown()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        pressUp()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        pressUp()
    }
    
    private func pressDown() {
        guard !isPressed else { return }
        isPressed = true
        
        onKeyEvent?(keyCode, true)
        
        // Visual feedback - ink spreading
        UIView.animate(withDuration: 0.08) {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            self.backgroundColor = UIColor(red: 0.35, green: 0.30, blue: 0.22, alpha: 0.35)
            self.layer.borderColor = UIColor(red: 0.25, green: 0.20, blue: 0.12, alpha: 0.8).cgColor
        }
        glowLayer.shadowOpacity = 0.5
        
        // For holdable buttons (attack), set up rapid-fire timer
        if holdable {
            holdTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self = self, self.isPressed else { return }
                self.onKeyEvent?(self.keyCode, true)
            }
        }
    }
    
    private func pressUp() {
        guard isPressed else { return }
        isPressed = false
        
        holdTimer?.invalidate()
        holdTimer = nil
        
        onKeyEvent?(keyCode, false)
        
        // Visual feedback - ink recede
        UIView.animate(withDuration: 0.15) {
            self.transform = .identity
            self.backgroundColor = UIColor(red: 0.88, green: 0.84, blue: 0.78, alpha: 0.25)
            self.layer.borderColor = UIColor(red: 0.35, green: 0.30, blue: 0.22, alpha: 0.6).cgColor
        }
        glowLayer.shadowOpacity = 0
    }
}
