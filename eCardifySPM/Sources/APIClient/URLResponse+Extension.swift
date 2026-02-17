import Foundation
import Dependencies

extension URLResponse {
    func isResponseOK() -> Bool {
        if let httpResponse = self as? HTTPURLResponse {
            return (200...299).contains(httpResponse.statusCode)
        }
        return false
    }
}
