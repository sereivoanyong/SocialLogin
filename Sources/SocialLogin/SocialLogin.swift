//
//  SocialLogin.swift
//
//  Created by Sereivoan Yong on 2/12/24.
//

#if os(iOS)

import UIKit
import FacebookLogin
import GoogleSignIn

public enum SocialLogin {

  // MARK: UIApplicationDelegate

  public static func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
    ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: UISceneDelegate

  public static func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    if let userActivity = options.userActivities.first {
      ApplicationDelegate.shared.application(.shared, continue: userActivity)
    }
  }

  public static func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
    for urlContext in urlContexts {
      if open(urlContext) {
        continue
      }
    }
  }

  public static func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    ApplicationDelegate.shared.application(.shared, continue: userActivity)
  }
}

extension SocialLogin {

  public static func `open`(_ urlContext: UIOpenURLContext) -> Bool {
    let url = urlContext.url
    let options = urlContext.options
    if ApplicationDelegate.shared.application(.shared, open: url, sourceApplication: options.sourceApplication, annotation: options.annotation) {
      return true
    }
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return false
  }
}

#endif
