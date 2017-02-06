/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation
import LoggerAPI

/**
* JSON utilities.
*/
public struct JSONUtils {

  /**
  * Converts the speficied string to a JSON object.
  */
  public static func convertStringToJSON(text: String?) -> [String:Any]? {
    let data = text?.data(using: String.Encoding.utf8)
    guard let nsData = data else {
      Log.error("Could not generate JSON object from string: \(String(describing: text))")
      return nil
    }
    if let json = try? JSONSerialization.jsonObject(with: nsData) {
      return (json as? [String:Any])
    }
    return nil
  }

  /**
  * Converts an array element contained in a JSON object to an array of Strings.
  * The fieldName argument should state the name of the JSON property that contains
  * the array.
  */
  public static func convertJSONArrayToStringArray(json: [String:Any], fieldName: String) -> [String] {
    if let array = json[fieldName] as? [Any] {
      return (array.map { String(describing: $0) })
    }
    return []
  }

}
