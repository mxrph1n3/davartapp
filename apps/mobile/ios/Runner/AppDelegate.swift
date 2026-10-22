import Contacts
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var apnsToken: String?
  private var pendingOpen: [String: String]?
  private var activeChatId: String = ""

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
      case "setActiveChat":
        let args = call.arguments as? [String: Any]
        activeChatId = args?["chatId"] as? String ?? ""
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
    registerContactsChannel(engineBridge.applicationRegistrar.messenger())
  }

  private func registerContactsChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "davart/contacts", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "load":
        self.loadAddressBook(result)
      case "openSettings":
        DispatchQueue.main.async {
          guard let url = URL(string: UIApplication.openSettingsURLString) else {
            result(false)
            return
          }
          UIApplication.shared.open(url, options: [:]) { opened in
            result(opened)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func contactsAuthorized(_ status: CNAuthorizationStatus) -> Bool {
    if status == .authorized { return true }
    if #available(iOS 18.0, *), status == .limited { return true }
    return false
  }

  private func loadAddressBook(_ result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let store = CNContactStore()
      let status = CNContactStore.authorizationStatus(for: .contacts)
      if self.contactsAuthorized(status) {
        DispatchQueue.global(qos: .userInitiated).async {
          let rows = self.readAddressBook(store)
          DispatchQueue.main.async {
            result(["granted": true, "contacts": rows])
          }
        }
        return
      }
      if status != .notDetermined {
        result(["granted": false, "prompted": false, "contacts": []])
        return
      }
      store.requestAccess(for: .contacts) { granted, _ in
        if !granted {
          DispatchQueue.main.async {
            result(["granted": false, "prompted": true, "contacts": []])
          }
          return
        }
        let rows = self.readAddressBook(store)
        DispatchQueue.main.async {
          result(["granted": true, "contacts": rows])
        }
      }
    }
  }

  private func readAddressBook(_ store: CNContactStore) -> [[String: Any]] {
    let keys: [CNKeyDescriptor] = [
      CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
      CNContactPhoneNumbersKey as CNKeyDescriptor,
    ]
    let request = CNContactFetchRequest(keysToFetch: keys)
    var rows: [[String: Any]] = []
    try? store.enumerateContacts(with: request) { contact, _ in
      let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
      let phones = contact.phoneNumbers.map { $0.value.stringValue }
      if phones.isEmpty { return }
      rows.append(["name": name, "phones": phones])
    }
    return rows
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
    let chatId = notification.request.content.userInfo["chatId"] as? String ?? ""
    let onThisChat = !activeChatId.isEmpty && chatId == activeChatId
    if UIApplication.shared.applicationState == .active && onThisChat {
      completionHandler([])
      return
    }
    completionHandler([.banner, .list, .sound, .badge])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    var open: [String: String] = [:]
    for (key, value) in info {
      guard let key = key as? String, key != "aps" else { continue }
      if let text = value as? String, !text.isEmpty {
        open[key] = text
      } else if let number = value as? NSNumber {
        open[key] = number.stringValue
      }
    }
    if open["type"] == nil, let chatId = open["chatId"], !chatId.isEmpty {
      open["type"] = "chat"
    }
    if open["chatId"] != nil || open["type"] != nil {
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
