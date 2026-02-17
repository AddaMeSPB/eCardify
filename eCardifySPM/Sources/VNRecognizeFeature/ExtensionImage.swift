import SwiftUI

extension Image {
    public func uiImage() -> UIImage? {
        let hostingController = UIHostingController(rootView: self)
        guard let view = hostingController.view else { return nil }

        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        let image = renderer.image { ctx in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        
        return image
    }

    public var cgImage: CGImage? {
        guard let uiImage = self.uiImage() else { return nil }
        return uiImage.cgImage
    }
}
