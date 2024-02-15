//
//  FBAuthenticationManager.swift
//
//  Created by Sereivoan Yong on 2/15/24.
//

import Foundation
import AuthenticationServices
import FacebookLogin

final public class FBAuthenticationManager: NSObject {

  public static let shared = FBAuthenticationManager()

  private let settings: Settings = .shared
  private let appID: String
  private let urlScheme: String
  private let callbackHost = "authorize"
  private var authenticationSession: ASWebAuthenticationSession!

  weak private var viewController: UIViewController?
  private var completion: ((Result<String?, ASWebAuthenticationSessionError>) -> Void)?

  public override init() {
    appID = settings.appID ?? "nil"
    urlScheme = "fb\(appID)"
  }

  public func logIn(viewController: UIViewController, completion: @escaping (Result<String?, ASWebAuthenticationSessionError>) -> Void) {
    self.viewController = viewController
    self.completion = completion

    let isFacebookAppInstalled = UIApplication.shared.canOpenURL(URL(string: "fbapi://")!)
    // https://developers.facebook.com/docs/facebook-login/guides/advanced/oidc-token/
    var urlComponents = URLComponents(string: "https://facebook.com/dialog/oauth")!
    urlComponents.queryItems = [
      URLQueryItem(name: "client_id", value: appID),
      URLQueryItem(name: "scope", value: "public_profile,email,openid"),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "redirect_uri", value: "\(urlScheme)://\(callbackHost)/"),
      URLQueryItem(name: "display", value: "touch"),
      // fbapp_pres, sdk, sdk_version are needed to allow logging in with the Facebook app
      URLQueryItem(name: "fbapp_pres", value: NSNumber(value: isFacebookAppInstalled).stringValue),
      URLQueryItem(name: "sdk", value: "ios"),
      URLQueryItem(name: "sdk_version", value: settings.sdkVersion)
    ]
    if let authenticationSession {
      authenticationSession.cancel()
    }
    let url = urlComponents.url!
    authenticationSession = ASWebAuthenticationSession(
      url: url,
      callbackURLScheme: urlScheme,
      completionHandler: { [unowned self] callbackURL, error in
        let result: Result<(URL, (URL) -> String?), ASWebAuthenticationSessionError>
        switch Result<URL, Error>(callbackURL, error)! {
        case .success(let callbackURL):
          result = .success((callbackURL, \.query))
        case .failure(let error):
          let error = error as! ASWebAuthenticationSessionError
          result = .failure(error)
        }
        complete(result)
      }
    )
    authenticationSession.presentationContextProvider = self
    authenticationSession.start()
  }

  public func complete(_ result: Result<(URL, (URL) -> String?), ASWebAuthenticationSessionError>) {
    switch result {
    case .success(let (url, parametersProvider)):
      var code: String?
      if let parameters = parametersProvider(url) {
        var dictionary: [String: String] = [:]
        let pairs = parameters.components(separatedBy: "&")
        for pair in pairs {
          if let separatorIndex = pair.firstIndex(of: "=") {
            let key = String(pair[..<separatorIndex])
            let value = String(pair[pair.index(separatorIndex, offsetBy: 1)...])
            dictionary[key] = value
          }
        }
        code = dictionary["code"]
      }
      completion?(.success(code))
    case .failure(let error):
      completion?(.failure(error))
    }
    completion = nil
  }

  public var hasPendingLogin: Bool {
    return completion != nil
  }

  // MARK:

  public func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
    for urlContext in urlContexts {
      if open(urlContext.url) {
        continue
      }
    }
  }

  public func `open`(_ url: URL) -> Bool {
    if url.scheme == urlScheme && url.host == callbackHost {
      if let authenticationSession {
        authenticationSession.cancel()
        self.authenticationSession = nil
      }
      complete(.success((url, \.fragment)))
      return true
    }
    return false
  }
}

extension FBAuthenticationManager: ASWebAuthenticationPresentationContextProviding {

  public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    if let viewController, viewController.isViewLoaded {
      if let window = viewController.view.window {
        return window
      }
    }
    return defaultWindow()
  }
}
