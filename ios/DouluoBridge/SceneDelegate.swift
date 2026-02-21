import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var splashView: UIImageView?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
        
        // Full-screen splash overlay (aspect-fill, no black borders)
        if let img = UIImage(named: "LaunchImage") {
            let splash = UIImageView(image: img)
            splash.contentMode = .scaleAspectFill
            splash.frame = window.bounds
            splash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            splash.clipsToBounds = true
            window.addSubview(splash)
            self.splashView = splash
            
            // Fade out after 1.5s (splash during SpriteKit scene setup)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                UIView.animate(withDuration: 0.5, animations: {
                    splash.alpha = 0
                }) { _ in
                    splash.removeFromSuperview()
                    self.splashView = nil
                }
            }
        }
    }
}
