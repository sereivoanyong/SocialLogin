//
//  Utilities.swift
//
//  Created by Sereivoan Yong on 2/15/24.
//

import UIKit

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

func defaultWindow() -> UIWindow {
  // https://stackoverflow.com/a/57899013/11235826
  return UIApplication.shared.windows.first(where: \.isKeyWindow) ?? UIWindow()
}
