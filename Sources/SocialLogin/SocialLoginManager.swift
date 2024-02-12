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

  public let id: String
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

final public class SocialLoginManager: NSObject {

  public static let shared = SocialLoginManager()

  private var appleInfo: (authorizationController: ASAuthorizationController, viewController: UIViewController?, completion: (SocialCredentialResult) -> Void)?

  var imageDimension: Int = 1024

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
  public func logInWithApple(viewController: UIViewController, completion: @escaping (SocialCredentialResult) -> Void) -> ASAuthorizationController {
    weak var viewController = viewController

    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.fullName, .email]

    let authorizationController = ASAuthorizationController(authorizationRequests: [request])
    appleInfo = (authorizationController, viewController, completion)
    authorizationController.delegate = self
    authorizationController.presentationContextProvider = self
    authorizationController.performRequests()
    return authorizationController
  }

  @discardableResult
  public func logInWithFacebook(viewController: UIViewController, loadProfile: Bool = true, completion: @escaping (SocialCredentialResult) -> Void) -> LoginManager {
    let loginManager = LoginManager()
    let configuration = LoginConfiguration(permissions: ["public_profile", "email"], tracking: .enabled)
    loginManager.logIn(viewController: viewController, configuration: configuration) { [unowned self] result in
      switch result {
      case .success(_, _, let accessToken):
        if let accessToken {
          let userId = accessToken.userID
          if loadProfile {
            Profile.loadCurrentProfile { [unowned self] profile, error in
              guard let result = Result(profile, error) else {
                let credential = SocialCredential(
                  provider: .facebook,
                  userId: userId,
                  profile: nil,
                  accessToken: accessToken.tokenString,
                  identityToken: AuthenticationToken.current?.tokenString,
                  authorizationCode: nil
                )
                completion(.success(credential))
                return
              }
              switch result {
              case .success(let profile):
                let imageDimension = CGFloat(imageDimension)
                let profile = SocialProfile(
                  id: profile.userID,
                  name: profile.name,
                  imageURL: profile.imageURL(forMode: .square, size: CGSize(width: imageDimension, height: imageDimension)),
                  email: profile.email
                )
                let credential = SocialCredential(
                  provider: .facebook,
                  userId: userId,
                  profile: profile,
                  accessToken: accessToken.tokenString,
                  identityToken: AuthenticationToken.current?.tokenString,
                  authorizationCode: nil
                )
                completion(.success(credential))
              case .failure(let error):
                let error = error as NSError
#if DEBUG
                print(error)
#endif
                completion(.failure(error))
              }
            }
          } else {
            let credential = SocialCredential(
              provider: .facebook,
              userId: userId,
              profile: nil,
              accessToken: accessToken.tokenString,
              identityToken: AuthenticationToken.current?.tokenString,
              authorizationCode: nil
            )
            completion(.success(credential))
          }
        } else {
          completion(.unknown)
        }

      case .cancelled:
        completion(.canceled)

      case .failed(let error):
#if DEBUG
        if let error = error as? LoginError {
          print(error)
        }
#endif
        completion(.failure(error))
      }
    }
    return loginManager
  }

  @discardableResult
  public func logInWithGoogle(viewController: UIViewController, completion: @escaping (SocialCredentialResult) -> Void) -> GIDSignIn {
    let signIn = GIDSignIn.sharedInstance
    signIn.signIn(withPresenting: viewController, hint: nil) { [unowned self] result, error in
      guard let result = Result(result, error) else {
        completion(.unknown)
        return
      }
      switch result {
      case .success(let result):
        let user = result.user
        let userId: String
        if let nonnilUserId = user.userID {
          userId = nonnilUserId
        } else {
#if DEBUG
          print("GoogleSignIn returned nil `userID`.")
#endif
          userId = "UNKNOWN"
        }
        let credential = SocialCredential(
          provider: .google,
          userId: userId,
          profile: SocialProfile(
            id: userId,
            name: user.profile?.name,
            imageURL: user.profile?.imageURL(withDimension: UInt(imageDimension)),
            email: user.profile?.email
          ),
          accessToken: result.user.accessToken.tokenString,
          identityToken: result.user.idToken?.tokenString,
          authorizationCode: result.serverAuthCode
        )
        completion(.success(credential))

      case .failure(let error):
        if let error = error as? GIDSignInError {
          if error.code == .canceled {
            completion(.canceled)
          } else {
#if DEBUG
            print(error)
#endif
            completion(.failure(error))
          }
        } else {
          completion(.failure(error))
        }
      }
    }
    return signIn
  }
}

extension SocialLoginManager: ASAuthorizationControllerDelegate {

  public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let appleInfo, appleInfo.authorizationController === controller else { return }

    let result: SocialCredentialResult
    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
      let userId = appleIDCredential.user
      let profile = SocialProfile(
        id: userId,
        name: appleIDCredential.fullName.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .long, options: []) },
        imageURL: nil,
        email: appleIDCredential.email
      )
      let credential = SocialCredential(
        provider: .apple,
        userId: userId,
        profile: profile,
        accessToken: nil,
        identityToken: appleIDCredential.identityToken.flatMap { String(data: $0, encoding: .utf8) },
        authorizationCode: appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
      )
      result = .success(credential)
    } else {
      result = .unknown
    }
    appleInfo.completion(result)
    self.appleInfo = nil
  }

  public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    guard let appleInfo, appleInfo.authorizationController === controller else { return }

    var result: SocialCredentialResult?
    if let error = error as? ASAuthorizationError {
      if error.code == .canceled {
        result = .canceled
      } else {
#if DEBUG
        print(error)
#endif
      }
    }
    appleInfo.completion(result ?? .failure(error))
    self.appleInfo = nil
  }
}

extension SocialLoginManager: ASAuthorizationControllerPresentationContextProviding {

  private func defaultWindow() -> UIWindow {
    // https://stackoverflow.com/a/57899013/11235826
    return UIApplication.shared.windows.first(where: \.isKeyWindow) ?? UIWindow()
  }

  public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    guard let appleInfo, appleInfo.authorizationController === controller else { return defaultWindow() }

    if let viewController = appleInfo.viewController, viewController.isViewLoaded {
      if let window = viewController.view.window {
        return window
      }
    }
    return defaultWindow()
  }
}

extension Result {

  init?(_ success: Success?, _ failure: Failure?) {
    if let success {
      self = .success(success)
    } else if let failure {
      self = .failure(failure)
    } else {
      return nil
    }
  }
}

#endif
