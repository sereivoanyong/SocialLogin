//
//  AuthorizationController.swift
//
//  Created by Sereivoan Yong on 2/16/24.
//

import Foundation
import AuthenticationServices

final public class AuthorizationController: NSObject {

  weak var viewController: UIViewController?

  let completion: (Result<ASAuthorization, ASAuthorizationError>) -> Void

  public init(viewController: UIViewController?, completion: @escaping (Result<ASAuthorization, ASAuthorizationError>) -> Void) {
    self.viewController = viewController
    self.completion = completion
  }

  public func perform() {
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.fullName, .email]

    let authorizationController = ASAuthorizationController(authorizationRequests: [request])
    authorizationController.delegate = self
    authorizationController.presentationContextProvider = self
    authorizationController.performRequests()
  }
}

extension AuthorizationController: ASAuthorizationControllerDelegate {

  public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    completion(.success(authorization))
  }

  public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    let error = error as! ASAuthorizationError
    completion(.failure(error))
  }
}

extension AuthorizationController: ASAuthorizationControllerPresentationContextProviding {

  public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    if let viewController, viewController.isViewLoaded {
      if let window = viewController.view.window {
        return window
      }
    }
    // https://stackoverflow.com/a/57899013/11235826
    return UIApplication.shared.windows.first(where: \.isKeyWindow) ?? UIWindow()
  }
}
