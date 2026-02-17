import UIKit
import WebKit

class GameViewController: UIViewController, WKScriptMessageHandler {
    
    private var webView: WKWebView!
    private var joystick: VirtualJoystick!
    private var jumpButton: ActionButton!
    private var dashButton: ActionButton!
    
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
        
        // Register haptic message handler
        config.userContentController.add(self, name: "haptic")
        
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
    
    private var attackButton: ActionButton!
    private var skillButtons: [ActionButton] = []
    
    private func setupControls() {
        let safeBottom: CGFloat = 20
        let buttonSize: CGFloat = 78
        let smallButtonSize: CGFloat = 60
        let skillSize: CGFloat = 48
        
        // Virtual Joystick (bottom-left)
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
        
        // Attack button (bottom-right, MAIN action - holdable for rapid fire)
        attackButton = ActionButton(
            label: "🏹",
            sublabel: "攻",
            color: UIColor(red: 0.65, green: 0.20, blue: 0.15, alpha: 1.0),
            keyCode: "KeyJ",
            holdable: true
        )
        attackButton.onKeyEvent = { [weak self] code, pressed in
            self?.sendKey(code, pressed: pressed)
        }
        view.addSubview(attackButton)
        attackButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            attackButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -30),
            attackButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -(safeBottom + 20)),
            attackButton.widthAnchor.constraint(equalToConstant: buttonSize),
            attackButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
        
        // Dash/Kill button (left of attack)
        dashButton = ActionButton(
            label: "🗡",
            sublabel: "杀",
            color: UIColor(red: 0.40, green: 0.28, blue: 0.15, alpha: 1.0),
            keyCode: "ShiftLeft",
            holdable: false
        )
        dashButton.onKeyEvent = { [weak self] code, pressed in
            self?.sendKey(code, pressed: pressed)
        }
        view.addSubview(dashButton)
        dashButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dashButton.trailingAnchor.constraint(equalTo: attackButton.leadingAnchor, constant: -12),
            dashButton.bottomAnchor.constraint(equalTo: attackButton.bottomAnchor),
            dashButton.widthAnchor.constraint(equalToConstant: smallButtonSize),
            dashButton.heightAnchor.constraint(equalToConstant: smallButtonSize)
        ])
        
        // Jump button (above attack)
        jumpButton = ActionButton(
            label: "⬆",
            sublabel: "跳",
            color: UIColor(red: 0.30, green: 0.28, blue: 0.25, alpha: 1.0),
            keyCode: "Space",
            holdable: false
        )
        jumpButton.onKeyEvent = { [weak self] code, pressed in
            self?.sendKey(code, pressed: pressed)
        }
        view.addSubview(jumpButton)
        jumpButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            jumpButton.trailingAnchor.constraint(equalTo: attackButton.trailingAnchor),
            jumpButton.bottomAnchor.constraint(equalTo: attackButton.topAnchor, constant: -8),
            jumpButton.widthAnchor.constraint(equalToConstant: smallButtonSize),
            jumpButton.heightAnchor.constraint(equalToConstant: smallButtonSize)
        ])
        
        // 5 Skill buttons (row above dash+attack area)
        let skills: [(String, String, UIColor, String)] = [
            ("🔥", "火", UIColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0), "KeyQ"),
            ("🌀", "风", UIColor(red: 0.0, green: 0.80, blue: 1.0, alpha: 1.0), "KeyE"),
            ("🛡", "盾", UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1.0), "KeyR"),
            ("⚡", "雷", UIColor(red: 0.67, green: 0.40, blue: 1.0, alpha: 1.0), "KeyT"),
            ("💀", "魂", UIColor(red: 0.20, green: 1.0, blue: 0.53, alpha: 1.0), "KeyY"),
        ]
        
        for (i, skill) in skills.enumerated() {
            let btn = ActionButton(
                label: skill.0,
                sublabel: skill.1,
                color: skill.2,
                keyCode: skill.3,
                holdable: false
            )
            btn.onKeyEvent = { [weak self] code, pressed in
                self?.sendKey(code, pressed: pressed)
            }
            view.addSubview(btn)
            btn.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                btn.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: CGFloat(-30 - i * Int(skillSize + 6))),
                btn.bottomAnchor.constraint(equalTo: jumpButton.topAnchor, constant: -8),
                btn.widthAnchor.constraint(equalToConstant: skillSize),
                btn.heightAnchor.constraint(equalToConstant: skillSize)
            ])
            skillButtons.append(btn)
        }
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
    
    // MARK: - Haptic Feedback (JS → Native)
    
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "haptic", let type = message.body as? String else { return }
        
        switch type {
        case "light":
            lightImpact.impactOccurred()
        case "medium":
            mediumImpact.impactOccurred()
        case "heavy":
            heavyImpact.impactOccurred()
        case "success":
            notificationFeedback.notificationOccurred(.success)
        case "warning":
            notificationFeedback.notificationOccurred(.warning)
        case "error":
            notificationFeedback.notificationOccurred(.error)
        default:
            lightImpact.impactOccurred()
        }
    }
}
