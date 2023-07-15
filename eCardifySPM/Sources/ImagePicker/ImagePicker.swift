//
//  ImagePickerViewRepresentable.swift
//  
//
//  Created by Saroar Khandoker on 11.10.2021.
//

import SwiftUI
import ComposableArchitecture
import PhotosUI
import Combine

extension PHPickerResult {
  public struct ImageError: Error {
    let message: String
  }

  func loadImage() -> Future<UIImage, ImageError> {
    return Future { promise in
      guard case let itemProvider = self.itemProvider,
        itemProvider.canLoadObject(ofClass: UIImage.self)
      else {
        return promise(.failure(ImageError(message: "Unable to load image.")))
      }

      itemProvider.loadObject(of: UIImage.self) { result in
        switch result {
        case let .success(image):
          return promise(.success(image))
        case let .failure(error):
          return promise(.failure(
            ImageError(message: "\(error.localizedDescription) Asset is not an image.")
          ))
        }
      }
    }
  }

    func loadImageContinuation() async throws -> UIImage {
        guard case let itemProvider = self.itemProvider,
              itemProvider.canLoadObject(ofClass: UIImage.self)
        else {
            throw ImageError(message: "Unable to load image.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            itemProvider.loadObject(of: UIImage.self) { result in
              switch result {
              case let .success(image):
                continuation.resume(with: .success(image))
              case let .failure(error):
                continuation.resume( with: .failure( ImageError(message: "\(error.localizedDescription) Asset is not an image.")))
              }
            }
        }

    }
}

public struct ImagePickerReducer: ReducerProtocol {

    public enum SelectType: String, Equatable {
        case single, multi
    }

    public struct State: Equatable {
      public var showingImagePicker: Bool
      public var image: UIImage?
      public var selectType: SelectType

      public init(showingImagePicker: Bool, selectType: SelectType, image: UIImage? = nil) {
        self.showingImagePicker = showingImagePicker
        self.selectType = selectType
        self.image = image
      }
    }

    public enum Action: Equatable {
        public static func == (lhs: ImagePickerReducer.Action, rhs: ImagePickerReducer.Action) -> Bool {
        return lhs.value == rhs.value
      }

      // only for Equatable
      var value: String? {
        return String(describing: self).components(separatedBy: "(").first
      }

      case setSheet(isPresented: Bool)

      case imagePicked(image: UIImage)

      case pickerResultReceived(result: PHPickerResult)
      case picked(result: UIImage)
      case dismissButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setSheet(isPresented: presented):
              state.showingImagePicker = presented
              return .none

            case let .imagePicked(image: image):
              state.image = image
              return .none

            case let .pickerResultReceived(result: result):
                return .run { send in
                    let image = try await result.loadImageContinuation()
                    await send(.picked(result: image))
                }

            case let .picked(result: image):
              state.image = image
              return .none

            case .dismissButtonTapped:
                return .fireAndForget { await self.dismiss() }
            }
        }
    }
}

public struct ImagePickerView: UIViewControllerRepresentable {

    let viewStore: ViewStoreOf<ImagePickerReducer>

    public init(store: StoreOf<ImagePickerReducer>) {
        self.viewStore = ViewStore(store)
    }

  public func makeUIViewController(
    context: UIViewControllerRepresentableContext<ImagePickerView>
  ) -> some UIViewController {
    var config = PHPickerConfiguration()
    config.filter = PHPickerFilter.images
    config.selectionLimit = viewStore.selectType == .single ? 1 : 6

    let picker = PHPickerViewController(configuration: config)
    picker.delegate = context.coordinator
    return picker
  }

  public func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}

  public func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  public class Coordinator: PHPickerViewControllerDelegate {
    let parent: ImagePickerView

    init(_ parent: ImagePickerView) {
      self.parent = parent
    }

    public func picker(
      _ picker: PHPickerViewController,
      didFinishPicking results: [PHPickerResult]
    ) {

      guard let result = results.first else {
          parent.viewStore.send(.dismissButtonTapped)
        return
      }

      parent.viewStore.send(.pickerResultReceived(result: result))

    }
  }
}

extension NSItemProvider {

    func loadObject<Object: NSItemProviderReading>(
      of type: Object.Type,
      completionHandler: @escaping (Result<Object, Error>) -> Void) {
        self.loadObject(ofClass: type) { object, error in
            if let error = error {
                completionHandler(.failure(error))
            } else if let object = object as? Object {
                completionHandler(.success(object))
            } else {
                let error = NSError(
                  domain: NSItemProvider.errorDomain,
                  code: NSItemProvider.ErrorCode.unknownError.rawValue)
                completionHandler(.failure(error))
            }
        }
    }

    func loadObjectPublisher<Object: NSItemProviderReading>(of type: Object.Type) -> AnyPublisher<Object, Error> {
        let subject = PassthroughSubject<Object, Error>()

        self.loadObject(of: type) { result in
            switch result {
            case .success(let object):
                subject.send(object)
            case .failure(let error):
                subject.send(completion: .failure(error))
            }
        }

        return subject.eraseToAnyPublisher()
    }
}
