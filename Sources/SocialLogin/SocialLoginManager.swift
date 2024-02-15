//
//  SocialLoginManager.swift
//
//  Created by Sereivoan Yong on 10/26/23.
//

#if os(iOS)

import UIKit
import AuthenticationServices
import FacebookLogin
import GoogleSignIn

public enum SocialLoginProvider: String, CaseIterable {

  case apple
  case facebook
  case google
}

public struct SocialProfile {

  public let name: String?
  public let imageURL: URL?
  public let email: String?
}

public struct SocialCredential {

  public let provider: SocialLoginProvider
  public let userId: String // Googles' is optional. You may compare against "UNKNOWN"
  public let profile: SocialProfile?
  public let accessToken: String?
  public let identityToken: String?
  public let authorizationCode: String?
}

public enum SocialCredentialResult {

  case success(SocialCredential)
  case failure(Error)
  case canceled
  case unknown
}

public enum SocialAuhorizationResult {

  case success(String?)
  case failure(Error)
  case canceled
  case unknown
}

final public class SocialLoginManager: NSObject {

  public static let shared = SocialLoginManager()

  private var appleController: AuthorizationController!

  // MARK: Log In

  @discardableResult
  public func logIn(with provider: SocialLoginProvider, loadProfile: Bool = true, viewController: UIViewController, completion: @escaping (SocialCredentialResult) -> Void) -> Any {
    switch provider {
    case .apple:
      return logInWithApple(viewController: viewController, completion: completion)

    case .facebook:
      return logInWithFacebook(viewController: viewController, loadProfile: loadProfile, completion: completion)

    case .google:
      return logInWithGoogle(viewController: viewController, completion: completion)
    }
  }

  @discardableResult
  public func logInWithApple(viewController: UIViewController, completion: @escaping (SocialCredentialResult) -> Void) -> NSObjectProtocol {
    appleController = AuthorizationController(viewController: viewController) { result in
      switch result {
      case .success(let authorization):
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
          completion(.unknown)
          return
        }
        let profile = SocialProfile(
          name: appleIDCredential.fullName.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .long, options: []) },
          imageURL: nil,
          email: appleIDCredential.email
        )
        let credential = SocialCredential(
          provider: .apple,
          userId: appleIDCredential.user,
          profile: profile,
          accessToken: nil,
          identityToken: appleIDCredential.identityToken.flatMap { String(data: $0, encoding: .utf8) },
          authorizationCode: appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        )
        completion(.success(credential))
      case .failure(let error):
        if error.code == .canceled {
          completion(.canceled)
        } else {
#if DEBUG
          print(error)
#endif
          completion(.failure(error))
        }
      }
    }
    appleController.perform()
    return appleController
  }

  @discardableResult
  public func logInWithFacebook(viewController: UIViewController, loadProfile: Bool = true, completion: @escaping (SocialCredentialResult) -> Void) -> LoginManager {
    let loginManager = LoginManager()
    let configuration = LoginConfiguration(permissions: ["public_profile", "email", "openid"], tracking: .enabled)
    loginManager.logIn(viewController: viewController, configuration: configuration) { result in
      switch result {
      case .success(_, _, let accessToken):
        let credential = SocialCredential(
          provider: .facebook,
          userId: accessToken?.userID ?? "UNKNOWN",
          profile: Profile.current.map { profile in
            SocialProfile(
              name: profile.name,
              imageURL: profile.imageURL,
              email: profile.email
            )
          },
          accessToken: accessToken?.tokenString,
          identityToken: AuthenticationToken.current?.tokenString,
          authorizationCode: nil
        )
        completion(.success(credential))

      case .cancelled:
        completion(.canceled)

      case .failed(let error):
        let error = error as! LoginError
#if DEBUG
        print(error)
#endif
        completion(.failure(error))
      }
    }
    return loginManager
  }

  @discardableResult
  public func logInWithGoogle(viewController: UIViewController, completion: @escaping (SocialCredentialResult) -> Void) -> GIDSignIn {
    let signIn = GIDSignIn.sharedInstance
    signIn.signIn(withPresenting: viewController, hint: nil) { result, error in
      guard let result = Result(result, error) else {
        completion(.unknown)
        return
      }
      switch result {
      case .success(let result):
        let user = result.user
        let credential = SocialCredential(
          provider: .google,
          userId: user.userID ?? "UNKNOWN",
          profile: user.profile.map { profile in
            SocialProfile(
              name: profile.name,
              imageURL: profile.imageURL(withDimension: 1024),
              email: profile.email
            )
          },
          accessToken: result.user.accessToken.tokenString,
          identityToken: result.user.idToken?.tokenString,
          authorizationCode: result.serverAuthCode
        )
        completion(.success(credential))

      case .failure(let error):
        let error = error as! GIDSignInError
        if error.code == .canceled {
          completion(.canceled)
        } else {
#if DEBUG
          print(error)
#endif
          completion(.failure(error))
        }
      }
    }
    return signIn
  }

  // MARK: Authorization Code

  @discardableResult
  public func authorize(with provider: SocialLoginProvider, viewController: UIViewController, completion: @escaping (SocialAuhorizationResult) -> Void) -> NSObjectProtocol {
    switch provider {
    case .apple:
      return authorizeWithApple(viewController: viewController, completion: completion)
    case .facebook:
      return authorizeWithFacebook(viewController: viewController, completion: completion)
    case .google:
      return authorizeWithGoogle(viewController: viewController, completion: completion)
    }
  }

  @discardableResult
  public func authorizeWithApple(viewController: UIViewController, completion: @escaping (SocialAuhorizationResult) -> Void) -> AuthorizationController {
    appleController = AuthorizationController(viewController: viewController) { result in
      switch result {
      case .success(let authorization):
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
          completion(.unknown)
          return
        }
        completion(.success(appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }))

      case .failure(let error):
        if error.code == .canceled {
          completion(.canceled)
        } else {
#if DEBUG
          print(error)
#endif
          completion(.failure(error))
        }
      }
    }
    appleController.perform()
    return appleController
  }

  @discardableResult
  public func authorizeWithFacebook(viewController: UIViewController, completion: @escaping (SocialAuhorizationResult) -> Void) -> FBAuthenticationManager {
    let authenticationManager = FBAuthenticationManager.shared
    authenticationManager.logIn(viewController: viewController) { result in
      switch result {
      case .success(let authorizationCode):
        completion(.success(authorizationCode))

      case .failure(let error):
        if error.code == .canceledLogin {
          completion(.canceled)
        } else {
#if DEBUG
          print(error)
#endif
          completion(.failure(error))
        }
      }
    }
    return authenticationManager
  }

  @discardableResult
  public func authorizeWithGoogle(viewController: UIViewController, completion: @escaping (SocialAuhorizationResult) -> Void) -> GIDSignIn {
    let signIn = GIDSignIn.sharedInstance
    signIn.signIn(withPresenting: viewController, hint: nil) {result, error in
      guard let result = Result(result, error) else {
        completion(.unknown)
        return
      }
      switch result {
      case .success(let result):
        completion(.success(result.serverAuthCode))

      case .failure(let error):
        let error = error as! GIDSignInError
        if error.code == .canceled {
          completion(.canceled)
        } else {
#if DEBUG
          print(error)
#endif
          completion(.failure(error))
        }
      }
    }
    return signIn
  }
}

#endif
