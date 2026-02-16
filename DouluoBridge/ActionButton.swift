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
        
        // Background
        backgroundColor = accentColor.withAlphaComponent(0.15)
        layer.cornerRadius = 16
        layer.borderColor = accentColor.withAlphaComponent(0.5).cgColor
        layer.borderWidth = 2
        
        // Glow layer
        glowLayer.shadowColor = accentColor.cgColor
        glowLayer.shadowRadius = 12
        glowLayer.shadowOpacity = 0
        glowLayer.shadowOffset = .zero
        layer.addSublayer(glowLayer)
        
        // Emoji label
        emojiLabel.text = label
        emojiLabel.font = .systemFont(ofSize: 24)
        emojiLabel.textAlignment = .center
        emojiLabel.isUserInteractionEnabled = false
        addSubview(emojiLabel)
        
        // Text label
        textLabel.text = sublabel
        textLabel.font = .boldSystemFont(ofSize: 10)
        textLabel.textColor = accentColor.withAlphaComponent(0.9)
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
        
        // Visual feedback
        UIView.animate(withDuration: 0.08) {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.backgroundColor = self.accentColor.withAlphaComponent(0.4)
            self.layer.borderColor = self.accentColor.withAlphaComponent(0.9).cgColor
        }
        glowLayer.shadowOpacity = 0.8
        
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
        
        // Visual feedback
        UIView.animate(withDuration: 0.12) {
            self.transform = .identity
            self.backgroundColor = self.accentColor.withAlphaComponent(0.15)
            self.layer.borderColor = self.accentColor.withAlphaComponent(0.5).cgColor
        }
        glowLayer.shadowOpacity = 0
    }
}
