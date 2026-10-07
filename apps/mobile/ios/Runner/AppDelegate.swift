import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var apnsToken: String?
  private var pendingOpen: [String: String]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    UNUserNotificationCenter.current().delegate = self
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    UNUserNotificationCenter.current().delegate = self
    let channel = FlutterMethodChannel(
      name: "davart/push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "register":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            result(granted)
            if let token = self.apnsToken {
              self.pushChannel?.invokeMethod("token", arguments: token)
            }
          }
        }
      case "show":
        let args = call.arguments as? [String: Any] ?? [:]
        self.showBanner(
          title: args["title"] as? String ?? "DAVart",
          body: args["body"] as? String ?? "Новое сообщение",
          chatId: args["chatId"] as? String ?? "",
          messageId: args["messageId"] as? String ?? UUID().uuidString
        )
        result(nil)
      case "pendingOpen":
        result(self.pendingOpen)
        self.pendingOpen = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    pushChannel = channel
    if let token = apnsToken {
      channel.invokeMethod("token", arguments: token)
    }
    if let pendingOpen {
      channel.invokeMethod("open", arguments: pendingOpen)
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    apnsToken = token
    pushChannel?.invokeMethod("token", arguments: token)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs registration failed: \(error.localizedDescription)")
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound, .badge])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    if let chatId = info["chatId"] as? String, !chatId.isEmpty {
      let title = (info["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      let open = ["chatId": chatId, "title": (title?.isEmpty == false ? title! : "Чат")]
      pendingOpen = open
      pushChannel?.invokeMethod("open", arguments: open)
    }
    completionHandler()
  }

  private func showBanner(title: String, body: String, chatId: String, messageId: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.threadIdentifier = chatId
    content.userInfo = ["type": "chat", "chatId": chatId, "title": title]
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .active
    }
    let request = UNNotificationRequest(identifier: messageId, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }
}
