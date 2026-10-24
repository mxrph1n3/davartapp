import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  // The app shows unread counts itself; the home-screen badge must not stay
  // stuck on an old push once the user has opened the app.
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    if #available(iOS 17.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      UIApplication.shared.applicationIconBadgeNumber = 0
    }
  }
}
