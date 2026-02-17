import UIKit
import WebKit

class GameViewController: UIViewController, WKScriptMessageHandler {
    
    private var webView: WKWebView!
    private var joystick: VirtualJoystick!
    private var jumpButton: ActionButton!
    private var dashButton: ActionButton!
    private var attackButton: ActionButton!
    // Skill buttons in SKILL_DEFS order: [fire, whirlwind, shield, lightning, ghost]
    private var skillButtons: [ActionButton] = []
    
    // Haptic generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Currently pressed joystick keys
    private var joystickLeftPressed = false
    private var joystickRightPressed = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupWebView()
        setupControls()
        loadGame()
    }
    
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var shouldAutorotate: Bool { true }
    
    // MARK: - Setup
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Register message handlers
        config.userContentController.add(self, name: "haptic")
        config.userContentController.add(self, name: "skillCooldown")
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Disable zooming
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupControls() {
        let safeBottom: CGFloat = 20
        let bigSize: CGFloat = 78
        let skillSize: CGFloat = 52
        let gap: CGFloat = 8
        
        // ── Virtual Joystick (bottom-left) ──
        joystick = VirtualJoystick(frame: CGRect(x: 0, y: 0, width: 160, height: 160))
        joystick.onDirectionChange = { [weak self] direction in
            self?.handleJoystickDirection(direction)
        }
        view.addSubview(joystick)
        joystick.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            joystick.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            joystick.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -(safeBottom)),
            joystick.widthAnchor.constraint(equalToConstant: 160),
            joystick.heightAnchor.constraint(equalToConstant: 160)
        ])
        
        // ── Main column (far right): Attack + Jump, same size ──
        
        // Attack button (bottom-right, holdable rapid fire)
        attackButton = ActionButton(
            label: "🏹", sublabel: "攻",
            color: UIColor(red: 0.65, green: 0.20, blue: 0.15, alpha: 1.0),
            keyCode: "KeyJ", holdable: true
        )
        attackButton.onKeyEvent = { [weak self] code, pressed in self?.sendKey(code, pressed: pressed) }
        view.addSubview(attackButton)
        attackButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            attackButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            attackButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -(safeBottom + 16)),
            attackButton.widthAnchor.constraint(equalToConstant: bigSize),
            attackButton.heightAnchor.constraint(equalToConstant: bigSize)
        ])
        
        // Jump button (same size as attack, directly above)
        jumpButton = ActionButton(
            label: "⬆", sublabel: "跳",
            color: UIColor(red: 0.30, green: 0.28, blue: 0.25, alpha: 1.0),
            keyCode: "Space", holdable: false
        )
        jumpButton.onKeyEvent = { [weak self] code, pressed in self?.sendKey(code, pressed: pressed) }
        view.addSubview(jumpButton)
        jumpButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            jumpButton.trailingAnchor.constraint(equalTo: attackButton.trailingAnchor),
            jumpButton.bottomAnchor.constraint(equalTo: attackButton.topAnchor, constant: -gap),
            jumpButton.widthAnchor.constraint(equalToConstant: bigSize),
            jumpButton.heightAnchor.constraint(equalToConstant: bigSize)
        ])
        
        // ── 6 smaller buttons: 2 rows × 3, to the left of attack+jump column ──
        //
        //  Screen right side layout:
        //    col3     col2     col1     main
        //   [⚡雷]  [🛡盾]  [🌀风]  [⬆跳 78]
        //   [💀魂]  [🔥火]  [🗡杀]  [🏹攻 78]
        //
        
        // Helper to create and position a button
        func makeButton(_ label: String, _ sublabel: String, _ color: UIColor,
                       _ keyCode: String, col: Int, row: UIView, locked: Bool = false) -> ActionButton {
            let btn = ActionButton(label: label, sublabel: sublabel, color: color, keyCode: keyCode, holdable: false)
            btn.onKeyEvent = { [weak self] code, pressed in self?.sendKey(code, pressed: pressed) }
            if locked { btn.setLocked(true) }
            view.addSubview(btn)
            btn.translatesAutoresizingMaskIntoConstraints = false
            let offset = -gap - CGFloat(col) * (skillSize + gap)
            NSLayoutConstraint.activate([
                btn.trailingAnchor.constraint(equalTo: attackButton.leadingAnchor, constant: offset),
                btn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                btn.widthAnchor.constraint(equalToConstant: skillSize),
                btn.heightAnchor.constraint(equalToConstant: skillSize)
            ])
            return btn
        }
        
        // Bottom row col1: 🗡杀 (dash, always active)
        dashButton = makeButton("🗡", "杀",
            UIColor(red: 0.40, green: 0.28, blue: 0.15, alpha: 1.0),
            "ShiftLeft", col: 1, row: attackButton)
        
        // Build skill buttons in SKILL_DEFS order: fire, whirlwind, shield, lightning, ghost
        // Bottom row col2: 🔥火 (fire, index 0)
        skillButtons.append(makeButton("🔥", "火",
            UIColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0),
            "KeyQ", col: 2, row: attackButton, locked: true))
        
        // Top row col1: 🌀风 (whirlwind, index 1)
        skillButtons.append(makeButton("🌀", "风",
            UIColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1.0),
            "KeyE", col: 1, row: jumpButton, locked: true))
        
        // Top row col2: 🛡盾 (shield, index 2)
        skillButtons.append(makeButton("🛡", "盾",
            UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1.0),
            "KeyR", col: 2, row: jumpButton, locked: true))
        
        // Top row col3: ⚡雷 (lightning, index 3)
        skillButtons.append(makeButton("⚡", "雷",
            UIColor(red: 0.67, green: 0.40, blue: 1.0, alpha: 1.0),
            "KeyT", col: 3, row: jumpButton, locked: true))
        
        // Bottom row col3: 💀魂 (ghost, index 4)
        skillButtons.append(makeButton("💀", "魂",
            UIColor(red: 0.20, green: 1.0, blue: 0.53, alpha: 1.0),
            "KeyY", col: 3, row: attackButton, locked: true))
    }
    
    private func loadGame() {
        guard let htmlPath = Bundle.main.path(forResource: "douluo_ios", ofType: "html") else {
            print("ERROR: douluo_ios.html not found in bundle")
            return
        }
        let htmlURL = URL(fileURLWithPath: htmlPath)
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }
    
    // MARK: - Input Handling
    
    private func handleJoystickDirection(_ direction: VirtualJoystick.Direction) {
        switch direction {
        case .left:
            if !joystickLeftPressed {
                sendKey("KeyA", pressed: true)
                joystickLeftPressed = true
            }
            if joystickRightPressed {
                sendKey("KeyD", pressed: false)
                joystickRightPressed = false
            }
        case .right:
            if !joystickRightPressed {
                sendKey("KeyD", pressed: true)
                joystickRightPressed = true
            }
            if joystickLeftPressed {
                sendKey("KeyA", pressed: false)
                joystickLeftPressed = false
            }
        case .none:
            if joystickLeftPressed {
                sendKey("KeyA", pressed: false)
                joystickLeftPressed = false
            }
            if joystickRightPressed {
                sendKey("KeyD", pressed: false)
                joystickRightPressed = false
            }
        }
    }
    
    private func sendKey(_ code: String, pressed: Bool) {
        let js = "window.iosSetKey('\(code)', \(pressed))"
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("JS Error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Message Handlers (JS → Native)
    
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        if message.name == "haptic", let type = message.body as? String {
            switch type {
            case "light": lightImpact.impactOccurred()
            case "medium": mediumImpact.impactOccurred()
            case "heavy": heavyImpact.impactOccurred()
            case "success": notificationFeedback.notificationOccurred(.success)
            case "warning": notificationFeedback.notificationOccurred(.warning)
            case "error": notificationFeedback.notificationOccurred(.error)
            default: lightImpact.impactOccurred()
            }
        } else if message.name == "skillCooldown", let data = message.body as? [String: Any] {
            // JS sends: { index: 0-4, ratio: 0.0-1.0, seconds: 2.5, level: 3 }
            guard let index = data["index"] as? Int,
                  let ratio = data["ratio"] as? Double,
                  let seconds = data["seconds"] as? Double,
                  let level = data["level"] as? Int,
                  index >= 0, index < skillButtons.count else { return }
            DispatchQueue.main.async {
                let btn = self.skillButtons[index]
                // Unlock/lock based on skill level
                btn.setLocked(level <= 0)
                if level > 0 {
                    btn.setCooldown(ratio: CGFloat(ratio), seconds: seconds)
                }
            }
        }
    }
}
