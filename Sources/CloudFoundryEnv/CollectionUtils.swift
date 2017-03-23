/**
* Copyright IBM Corporation 2017
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

extension Array
{
  func toDictionary<K, V>(converter: (Element) -> (K, V)) -> Dictionary<K, V> {
    var dict = Dictionary<K,V>()
    self.forEach({ item in
      let (k,v) = converter(item)
      dict[k] = v
    })
    return dict
  }
}

extension Dictionary where Key: ExpressibleByStringLiteral, Value: Any {
  func filterWithRegex(regex: String) -> Dictionary<Key, Value> {
    return self.filter({
      let k: String = String(describing: $0.key)
      return (k.range(of: regex, options: .regularExpression) != nil)
    }).toDictionary(converter: {$0})
  }
}
