import UIKit
import SpriteKit

class GameViewController: UIViewController, GameSceneDelegate {
    
    // MARK: - Properties
    private var skView: SKView!
    private var gameScene: GameScene!
    
    // Controls (reused from original)
    private var joystick: VirtualJoystick!
    private var jumpButton: ActionButton!
    private var dashButton: ActionButton!
    private var attackButton: ActionButton!
    private var ultButton: ActionButton!
    private var skillButtons: [ActionButton] = []
    private var allControls: [UIView] = []
    
    // Haptic generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .rigid)
    
    // Joystick state tracking
    private var joystickLeftPressed = false
    private var joystickRightPressed = false
    
    // HUD views
    private var hudContainer: UIView!
    private var hpBar: UIView!
    private var hpFill: UIView!
    private var ultBar: UIView!
    private var ultFill: UIView!
    private var killLabel: UILabel!
    private var comboLabel: UILabel!
    private var weaponLabel: UILabel!
    private var levelLabel: UILabel!
    
    // Menu views
    private var mainMenuView: UIView!
    private var gameOverView: UIView!
    private var pauseOverlay: UIView!
    private var levelBanner: UIView!
    private var levelBannerTitle: UILabel!
    
    // Audio
    private var audioManager: AudioManager!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        audioManager = AudioManager()
        
        setupSKView()
        setupHUD()
        setupMainMenu()
        setupGameOver()
        setupPauseOverlay()
        setupLevelBanner()
        setupControls()
        
        setControlsVisible(false, animated: false)
    }
    
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var shouldAutorotate: Bool { true }
    
    // MARK: - SpriteKit Setup
    
    private func setupSKView() {
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        view.addSubview(skView)
        
        gameScene = GameScene(size: CGSize(width: Physics.gameWidth, height: Physics.gameHeight))
        gameScene.scaleMode = .resizeFill  // Fill entire screen, no black bars
        gameScene.gameDelegate = self
        skView.presentScene(gameScene)
    }
    
    // MARK: - HUD Setup
    
    private func setupHUD() {
        hudContainer = UIView()
        hudContainer.isHidden = true
        hudContainer.isUserInteractionEnabled = false
        view.addSubview(hudContainer)
        hudContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hudContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            hudContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            hudContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            hudContainer.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // HP Bar
        hpBar = UIView()
        hpBar.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.8)
        hpBar.layer.borderColor = UIColor(red: 0.44, green: 0.24, blue: 0.07, alpha: 1).cgColor
        hpBar.layer.borderWidth = 1
        hudContainer.addSubview(hpBar)
        hpBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hpBar.topAnchor.constraint(equalTo: hudContainer.topAnchor),
            hpBar.leadingAnchor.constraint(equalTo: hudContainer.leadingAnchor),
            hpBar.widthAnchor.constraint(equalToConstant: 200),
            hpBar.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        hpFill = UIView()
        hpFill.backgroundColor = UIColor(red: 0.85, green: 0.16, blue: 0.16, alpha: 1)
        hpBar.addSubview(hpFill)
        
        // Ult Bar
        ultBar = UIView()
        ultBar.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.8)
        ultBar.layer.borderColor = UIColor(red: 0.44, green: 0.24, blue: 0.07, alpha: 1).cgColor
        ultBar.layer.borderWidth = 1
        hudContainer.addSubview(ultBar)
        ultBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ultBar.topAnchor.constraint(equalTo: hpBar.bottomAnchor, constant: 4),
            ultBar.leadingAnchor.constraint(equalTo: hudContainer.leadingAnchor),
            ultBar.widthAnchor.constraint(equalToConstant: 200),
            ultBar.heightAnchor.constraint(equalToConstant: 6)
        ])
        
        ultFill = UIView()
        ultFill.backgroundColor = UIColor(red: 0.92, green: 0.70, blue: 0.03, alpha: 1)
        ultBar.addSubview(ultFill)
        
        // Kill counter — positioned with enough offset to not be blocked by top-right buttons
        killLabel = UILabel()
        killLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        killLabel.textColor = UIColor(white: 1, alpha: 0.9)
        killLabel.text = "KILLS: 0"
        hudContainer.addSubview(killLabel)
        killLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            killLabel.topAnchor.constraint(equalTo: hudContainer.topAnchor),
            killLabel.trailingAnchor.constraint(equalTo: hudContainer.trailingAnchor, constant: -120)
        ])
        
        // Combo counter
        comboLabel = UILabel()
        comboLabel.font = .monospacedDigitSystemFont(ofSize: 24, weight: .heavy)
        comboLabel.textColor = UIColor(red: 0.92, green: 0.70, blue: 0.03, alpha: 1)
        comboLabel.text = ""
        comboLabel.textAlignment = .center
        hudContainer.addSubview(comboLabel)
        comboLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            comboLabel.centerXAnchor.constraint(equalTo: hudContainer.centerXAnchor),
            comboLabel.topAnchor.constraint(equalTo: hudContainer.topAnchor)
        ])
        
        // Weapon rank
        weaponLabel = UILabel()
        weaponLabel.font = .boldSystemFont(ofSize: 14)
        weaponLabel.textColor = .white
        weaponLabel.text = "木剑"
        hudContainer.addSubview(weaponLabel)
        weaponLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            weaponLabel.topAnchor.constraint(equalTo: ultBar.bottomAnchor, constant: 4),
            weaponLabel.leadingAnchor.constraint(equalTo: hudContainer.leadingAnchor)
        ])
        
        // Level display — below weapon label, dark text
        levelLabel = UILabel()
        levelLabel.font = .boldSystemFont(ofSize: 13)
        levelLabel.textColor = UIColor(red: 0.3, green: 0.25, blue: 0.18, alpha: 1)
        levelLabel.textAlignment = .left
        hudContainer.addSubview(levelLabel)
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            levelLabel.topAnchor.constraint(equalTo: weaponLabel.bottomAnchor, constant: 2),
            levelLabel.leadingAnchor.constraint(equalTo: hudContainer.leadingAnchor)
        ])
    }
    
    // MARK: - Main Menu
    
    private func setupMainMenu() {
        mainMenuView = UIView()
        mainMenuView.backgroundColor = .black
        view.addSubview(mainMenuView)
        mainMenuView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainMenuView.topAnchor.constraint(equalTo: view.topAnchor),
            mainMenuView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mainMenuView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainMenuView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        mainMenuView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: mainMenuView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: mainMenuView.centerYAnchor)
        ])
        
        // Version tag
        let versionLabel = UILabel()
        versionLabel.text = "PIXEL WUXIA v1.2"
        versionLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        versionLabel.textColor = UIColor(white: 1, alpha: 0.3)
        stack.addArrangedSubview(versionLabel)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "斗罗大桥"
        titleLabel.font = UIFont(name: "PingFangSC-Heavy", size: 64) ?? .boldSystemFont(ofSize: 64)
        titleLabel.textColor = .white
        titleLabel.layer.shadowColor = UIColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 0.9).cgColor
        titleLabel.layer.shadowRadius = 15
        titleLabel.layer.shadowOpacity = 1
        titleLabel.layer.shadowOffset = .zero
        stack.addArrangedSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "万剑归宗 | Ten Thousand Swords"
        subtitleLabel.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)
        stack.addArrangedSubview(subtitleLabel)
        
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 16).isActive = true
        stack.addArrangedSubview(spacer)
        
        // Start button
        var startConfig = UIButton.Configuration.plain()
        startConfig.title = "杀出血路"
        startConfig.baseForegroundColor = .white
        startConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 48, bottom: 16, trailing: 48)
        let startBtn = UIButton(configuration: startConfig)
        startBtn.titleLabel?.font = UIFont(name: "PingFangSC-Heavy", size: 28) ?? .boldSystemFont(ofSize: 28)
        startBtn.layer.borderWidth = 3
        startBtn.layer.borderColor = UIColor.white.cgColor
        startBtn.addTarget(self, action: #selector(startGameTapped), for: .touchUpInside)
        stack.addArrangedSubview(startBtn)
    }
    
    @objc private func startGameTapped() {
        mainMenuView.isHidden = true
        gameScene.startGame()
        audioManager.startBGM(songId: 0, bpm: 100)
    }
    
    // MARK: - Game Over
    
    private func setupGameOver() {
        gameOverView = UIView()
        gameOverView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        gameOverView.isHidden = true
        view.addSubview(gameOverView)
        gameOverView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gameOverView.topAnchor.constraint(equalTo: view.topAnchor),
            gameOverView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            gameOverView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameOverView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        gameOverView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: gameOverView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: gameOverView.centerYAnchor)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "气尽人亡"
        titleLabel.tag = 100
        titleLabel.font = UIFont(name: "PingFangSC-Heavy", size: 48) ?? .boldSystemFont(ofSize: 48)
        titleLabel.textColor = UIColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 1)
        stack.addArrangedSubview(titleLabel)
        
        let statsLabel = UILabel()
        statsLabel.tag = 101
        statsLabel.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
        statsLabel.textColor = UIColor(white: 1, alpha: 0.7)
        statsLabel.numberOfLines = 0
        statsLabel.textAlignment = .center
        stack.addArrangedSubview(statsLabel)
        
        var restartConfig = UIButton.Configuration.plain()
        restartConfig.title = "转世再来"
        restartConfig.baseForegroundColor = UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)
        restartConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 36, bottom: 12, trailing: 36)
        let restartBtn = UIButton(configuration: restartConfig)
        restartBtn.titleLabel?.font = UIFont(name: "PingFangSC-Heavy", size: 20) ?? .boldSystemFont(ofSize: 20)
        restartBtn.layer.borderWidth = 2
        restartBtn.layer.borderColor = UIColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 1).cgColor
        restartBtn.addTarget(self, action: #selector(restartTapped), for: .touchUpInside)
        stack.addArrangedSubview(restartBtn)
    }
    
    @objc private func restartTapped() {
        gameOverView.isHidden = true
        gameScene.startGame()
    }
    
    // MARK: - Pause Overlay
    
    private func setupPauseOverlay() {
        pauseOverlay = UIView()
        pauseOverlay.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        pauseOverlay.isHidden = true
        view.addSubview(pauseOverlay)
        pauseOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pauseOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            pauseOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pauseOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pauseOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let pauseLabel = UILabel()
        pauseLabel.text = "暂 停"
        pauseLabel.font = UIFont(name: "PingFangSC-Heavy", size: 56) ?? .boldSystemFont(ofSize: 56)
        pauseLabel.textColor = UIColor(red: 0.75, green: 0.69, blue: 0.56, alpha: 1)
        pauseOverlay.addSubview(pauseLabel)
        pauseLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pauseLabel.centerXAnchor.constraint(equalTo: pauseOverlay.centerXAnchor),
            pauseLabel.centerYAnchor.constraint(equalTo: pauseOverlay.centerYAnchor)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(resumeTapped))
        pauseOverlay.addGestureRecognizer(tapGesture)
    }
    
    @objc private func resumeTapped() {
        gameScene.resumeGame()
    }
    
    // MARK: - Level Banner
    
    private func setupLevelBanner() {
        levelBanner = UIView()
        levelBanner.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8)
        levelBanner.isHidden = true
        view.addSubview(levelBanner)
        levelBanner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            levelBanner.topAnchor.constraint(equalTo: view.topAnchor),
            levelBanner.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            levelBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            levelBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        levelBannerTitle = UILabel()
        levelBannerTitle.font = UIFont(name: "PingFangSC-Heavy", size: 48) ?? .boldSystemFont(ofSize: 48)
        levelBannerTitle.textColor = UIColor(red: 0.75, green: 0.69, blue: 0.56, alpha: 1)
        levelBannerTitle.textAlignment = .center
        levelBanner.addSubview(levelBannerTitle)
        levelBannerTitle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            levelBannerTitle.centerXAnchor.constraint(equalTo: levelBanner.centerXAnchor),
            levelBannerTitle.centerYAnchor.constraint(equalTo: levelBanner.centerYAnchor)
        ])
    }
    
    // MARK: - Controls Setup
    
    private func setupControls() {
        let safeBottom: CGFloat = 20
        let bigSize: CGFloat = 78
        let skillSize: CGFloat = 48
        let gap: CGFloat = 4
        
        // Virtual Joystick
        joystick = VirtualJoystick(frame: CGRect(x: 0, y: 0, width: 140, height: 140))
        joystick.onDirectionChange = { [weak self] dir in self?.handleJoystickDirection(dir) }
        view.addSubview(joystick)
        joystick.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            joystick.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            joystick.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -safeBottom),
            joystick.widthAnchor.constraint(equalToConstant: 140),
            joystick.heightAnchor.constraint(equalToConstant: 140)
        ])
        allControls.append(joystick)
        
        // Attack button
        attackButton = ActionButton(label: "🏹", sublabel: "攻",
            color: UIColor(red: 0.65, green: 0.20, blue: 0.15, alpha: 1.0),
            keyCode: "KeyJ", holdable: true)
        attackButton.onKeyEvent = { [weak self] _, pressed in
            if pressed { self?.gameScene.handleAttack() }
        }
        view.addSubview(attackButton)
        attackButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            attackButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            attackButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -safeBottom),
            attackButton.widthAnchor.constraint(equalToConstant: bigSize),
            attackButton.heightAnchor.constraint(equalToConstant: bigSize)
        ])
        allControls.append(attackButton)
        
        // Jump button
        jumpButton = ActionButton(label: "⬆", sublabel: "跳",
            color: UIColor(red: 0.20, green: 0.50, blue: 0.65, alpha: 1.0),
            keyCode: "Space", holdable: false)
        jumpButton.onKeyEvent = { [weak self] _, pressed in
            if pressed { self?.gameScene.handleJump() }
        }
        view.addSubview(jumpButton)
        jumpButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            jumpButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            jumpButton.bottomAnchor.constraint(equalTo: attackButton.topAnchor, constant: -gap),
            jumpButton.widthAnchor.constraint(equalToConstant: bigSize),
            jumpButton.heightAnchor.constraint(equalToConstant: bigSize)
        ])
        allControls.append(jumpButton)
        
        // Skill button helper
        func makeButton(_ label: String, _ sublabel: String, _ color: UIColor,
                         _ skillId: String, col: Int, row: UIView, locked: Bool = false) -> ActionButton {
            let btn = ActionButton(label: label, sublabel: sublabel, color: color,
                                   keyCode: skillId, holdable: false)
            btn.onKeyEvent = { [weak self] code, pressed in
                if pressed { self?.gameScene.handleSkill(code) }
            }
            if locked { btn.setLocked(true) }
            view.addSubview(btn)
            btn.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                btn.trailingAnchor.constraint(equalTo: row.leadingAnchor, constant: -gap - CGFloat(col - 1) * (skillSize + gap)),
                btn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                btn.widthAnchor.constraint(equalToConstant: skillSize),
                btn.heightAnchor.constraint(equalToConstant: skillSize)
            ])
            allControls.append(btn)
            return btn
        }
        
        // Dash button (col 1, bottom row)
        dashButton = makeButton("🗡", "杀",
            UIColor(red: 0.40, green: 0.28, blue: 0.15, alpha: 1.0),
            "dash", col: 1, row: attackButton)
        dashButton.onKeyEvent = { [weak self] _, pressed in
            if pressed { self?.gameScene.handleDash() }
        }
        
        // Skill buttons
        skillButtons.append(makeButton("🔥", "火",
            UIColor(red: 1.0, green: 0.27, blue: 0, alpha: 1.0),
            "fire", col: 2, row: attackButton, locked: true))
        
        skillButtons.append(makeButton("🌀", "风",
            UIColor(red: 0, green: 0.80, blue: 1.0, alpha: 1.0),
            "whirlwind", col: 1, row: jumpButton, locked: true))
        
        skillButtons.append(makeButton("🛡", "盾",
            UIColor(red: 1.0, green: 0.80, blue: 0, alpha: 1.0),
            "shield", col: 2, row: jumpButton, locked: true))
        
        skillButtons.append(makeButton("⚡", "雷",
            UIColor(red: 0.67, green: 0.40, blue: 1.0, alpha: 1.0),
            "lightning", col: 3, row: jumpButton, locked: true))
        
        skillButtons.append(makeButton("💀", "魂",
            UIColor(red: 0.20, green: 1.0, blue: 0.53, alpha: 1.0),
            "ghost", col: 3, row: attackButton, locked: true))
        
        // (Ultimate button removed — ult is triggered via energy bar, no dedicated button needed)
        
        // Home button
        let homeBtn = ActionButton(label: "🏠", sublabel: "",
            color: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),
            keyCode: "home", holdable: false)
        homeBtn.onKeyEvent = { [weak self] _, pressed in
            if pressed { self?.returnHome() }
        }
        view.addSubview(homeBtn)
        homeBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            homeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            homeBtn.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            homeBtn.widthAnchor.constraint(equalToConstant: 40),
            homeBtn.heightAnchor.constraint(equalToConstant: 40)
        ])
        allControls.append(homeBtn)
        // Remove circle styling from home button
        homeBtn.backgroundColor = .clear
        homeBtn.layer.borderWidth = 0
        homeBtn.layer.shadowOpacity = 0
        
        // Pause button — to the left of home button
        let pauseBtn = ActionButton(label: "⏸", sublabel: "",
            color: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),
            keyCode: "pause", holdable: false)
        pauseBtn.onKeyEvent = { [weak self] _, pressed in
            if pressed { self?.gameScene.pauseGame() }
        }
        view.addSubview(pauseBtn)
        pauseBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pauseBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            pauseBtn.trailingAnchor.constraint(equalTo: homeBtn.leadingAnchor, constant: -8),
            pauseBtn.widthAnchor.constraint(equalToConstant: 40),
            pauseBtn.heightAnchor.constraint(equalToConstant: 40)
        ])
        allControls.append(pauseBtn)
        // Remove circle styling from pause button
        pauseBtn.backgroundColor = .clear
        pauseBtn.layer.borderWidth = 0
        pauseBtn.layer.shadowOpacity = 0
    }
    
    private func returnHome() {
        gameScene.gameState = .menu
        audioManager.stopBGM()
        setControlsVisible(false, animated: true)
        mainMenuView.isHidden = false
        gameOverView.isHidden = true
        pauseOverlay.isHidden = true
        hudContainer.isHidden = true
    }
    
    // MARK: - Input
    
    private func handleJoystickDirection(_ direction: VirtualJoystick.Direction) {
        switch direction {
        case .left:
            gameScene.inputLeft = true
            gameScene.inputRight = false
        case .right:
            gameScene.inputLeft = false
            gameScene.inputRight = true
        case .none:
            gameScene.inputLeft = false
            gameScene.inputRight = false
        }
    }
    
    // MARK: - Control Visibility
    
    private func setControlsVisible(_ visible: Bool, animated: Bool) {
        let targetAlpha: CGFloat = visible ? 1.0 : 0.0
        if animated {
            UIView.animate(withDuration: 0.3) {
                for ctrl in self.allControls { ctrl.alpha = targetAlpha }
            }
        } else {
            for ctrl in self.allControls { ctrl.alpha = targetAlpha }
        }
    }
    
    // MARK: - GameSceneDelegate
    
    func gameStateChanged(_ state: GameScene.GameState) {
        DispatchQueue.main.async {
            switch state {
            case .menu:
                self.mainMenuView.isHidden = false
                self.hudContainer.isHidden = true
                self.gameOverView.isHidden = true
                self.pauseOverlay.isHidden = true
                self.setControlsVisible(false, animated: true)
                
            case .playing:
                self.mainMenuView.isHidden = true
                self.hudContainer.isHidden = false
                self.gameOverView.isHidden = true
                self.pauseOverlay.isHidden = true
                self.levelBanner.isHidden = true
                self.setControlsVisible(true, animated: true)
                for ctrl in self.allControls {
                    ctrl.isUserInteractionEnabled = true
                }
                
            case .paused:
                self.pauseOverlay.isHidden = false
                
            case .gameOver:
                self.setControlsVisible(false, animated: true)
                for ctrl in self.allControls {
                    ctrl.isUserInteractionEnabled = false
                }
                
            case .levelTransition:
                break
            }
        }
    }
    
    func updateHUD(hp: Int, maxHp: Int, energy: Int, kills: Int, combo: Int, weaponLevel: Int, level: Int) {
        DispatchQueue.main.async {
            let hpRatio = CGFloat(hp) / CGFloat(maxHp)
            self.hpFill.frame = CGRect(x: 0, y: 0, width: 200 * hpRatio, height: 12)
            
            let ultRatio = CGFloat(energy) / 100.0
            self.ultFill.frame = CGRect(x: 0, y: 0, width: 200 * ultRatio, height: 6)
            
            self.killLabel.text = "KILLS: \(kills)"
            
            if combo > 1 {
                self.comboLabel.text = "\(combo) COMBO!"
                self.comboLabel.isHidden = false
            } else {
                self.comboLabel.isHidden = true
            }
            
            let wIdx = max(0, min(weaponLevel - 1, GameConfig.weaponNames.count - 1))
            self.weaponLabel.text = "\(GameConfig.weaponNames[wIdx]) Lv.\(weaponLevel)"
            
            let lvlDef = GameConfig.levels[max(0, min(level - 1, 9))]
            self.levelLabel.text = lvlDef.name
            
            // Update skill button lock states
            let skillIds = GameConfig.skillDefs.map { $0.id }
            for (i, btn) in self.skillButtons.enumerated() {
                if i < skillIds.count {
                    let sk = self.gameScene.playerNode.skills[skillIds[i]]
                    btn.setLocked((sk?.level ?? 0) <= 0)
                    if let sk = sk, sk.level > 0 {
                        let cd = CGFloat(sk.cooldown)
                        let maxCd = CGFloat(GameConfig.skillDefs[i].baseCooldown)
                        btn.setCooldown(ratio: cd / maxCd, seconds: Double(cd / 60.0))
                    }
                }
            }
            
            // Dash (杀) cooldown display
            let dashCd = CGFloat(self.gameScene.playerNode.dashCooldown)
            let dashMaxCd: CGFloat = 35.0
            self.dashButton.setCooldown(ratio: dashCd / dashMaxCd, seconds: Double(dashCd / 60.0))
        }
    }
    
    func showLevelBanner(_ name: String) {
        DispatchQueue.main.async {
            // Switch BGM to match current level — different BPM per level for variety
            let songId = self.gameScene.currentLevel - 1
            // BPM by level: [Lv1-Heroic:110, Lv2-Carefree:105, Lv3-Martial:140, Lv4-Ambush:135,
            //  Lv5-Archery:115, Lv6-Blades:145, Lv7-Dragon:138, Lv8-Moon:90, Lv9-Ethereal:80, Lv10-Plum:100]
            let bpmTable: [Float] = [110, 105, 140, 135, 115, 145, 138, 90, 80, 100]
            let bpm = bpmTable[min(songId, bpmTable.count - 1)]
            print("[GameVC] Level \(self.gameScene.currentLevel) → switching BGM to songId \(songId), bpm \(bpm)")
            self.audioManager.changeSong(songId: songId, bpm: bpm)
            
            self.levelBannerTitle.text = name
            self.levelBanner.isHidden = false
            self.levelBanner.alpha = 0
            UIView.animate(withDuration: 0.5, animations: {
                self.levelBanner.alpha = 1
            }) { _ in
                UIView.animate(withDuration: 0.5, delay: 1.5, options: [], animations: {
                    self.levelBanner.alpha = 0
                }) { _ in
                    self.levelBanner.isHidden = true
                }
            }
        }
    }
    
    func gameEnded(kills: Int, time: Int, level: Int, victory: Bool) {
        DispatchQueue.main.async {
            self.audioManager.stopBGM()
            
            let titleLabel = self.gameOverView.viewWithTag(100) as? UILabel
            titleLabel?.text = victory ? "剑神归位" : "气尽人亡"
            
            let statsLabel = self.gameOverView.viewWithTag(101) as? UILabel
            let timeStr = String(format: "%d:%02d", time / 3600, (time / 60) % 60)
            statsLabel?.text = "击杀: \(kills)  |  时间: \(timeStr)  |  到达: 第\(level)关"
            
            self.gameOverView.isHidden = false
        }
    }
    
    func triggerHaptic(_ type: HapticType) {
        switch type {
        case .light: lightImpact.impactOccurred()
        case .medium: mediumImpact.impactOccurred()
        case .heavy: heavyImpact.impactOccurred()
        }
    }
}
