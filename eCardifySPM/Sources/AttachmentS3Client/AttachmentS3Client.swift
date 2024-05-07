//
//  AttachmentClient.swift
//
//
//  Created by Saroar Khandoker on 27.01.2021.
//

import UIKit
import SotoS3
import Combine
import InfoPlist
import Foundation
import Dependencies
import KeychainClient
import FoundationExtension

enum UploadError: Error {
    case compressError
    case putObjectError(String)
}

public struct ImageUploadOptions {

    public let passId: String // pass SerialNumber A value that uniquely identifies the pass.
    public let compressionQuality: CompressionQuality
    public let type: ImageType
    public let passImagesType: PassImagesType
    public let userId: String?

    public init(
        passId: String,
        compressionQuality: CompressionQuality,
        type: ImageType,
        passImagesType: PassImagesType,
        userId: String?
    ) {
        self.passId = passId
        self.compressionQuality = compressionQuality
        self.type = type
        self.passImagesType = passImagesType
        self.userId = userId
    }

}

public struct AttachmentS3Client {

    public static let bucket = "ecardify"
    public static var bucketWithEndpoint = "https://ecardify.ams3.digitaloceanspaces.com/"

    static public let client = AWSClient(
        credentialProvider: .static(
            accessKeyId: EnvironmentKeys.accessKeyId,
            secretAccessKey: EnvironmentKeys.secretAccessKey
        ),
        httpClientProvider: .createNew
    )

    public static let awsS3 = S3(
        client: client,
        region: .eunorth1,
        endpoint: "https://ams3.digitaloceanspaces.com"
    ).with(middlewares: [AWSLoggingMiddleware()])

    public typealias UploadImageToS3Handler = @Sendable (UIImage, ImageUploadOptions) async throws -> String
    public typealias UploadImagesToS3Handler = @Sendable ([UIImage], ImageUploadOptions) async throws -> [String]

    public let uploadImageToS3: UploadImageToS3Handler
    public let uploadImagesToS3: UploadImagesToS3Handler

    public init(
        uploadImageToS3: @escaping UploadImageToS3Handler,
        uploadImagesToS3: @escaping UploadImagesToS3Handler
    ) {
        self.uploadImageToS3 = uploadImageToS3
        self.uploadImagesToS3 = uploadImagesToS3
    }
}

extension AttachmentS3Client {

    static public func buildImageKey(with options: ImageUploadOptions) -> String {
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        var imageKey = String(format: "%ld", currentTime) // make it pass id
        if let userId = options.userId {
            imageKey = "uploads/images/\(userId)/\(options.passId)/\(options.passImagesType.rawValue).\(options.type.rawValue)"
        }

        return imageKey
    }

    // upload image to DigitalOcen Spaces
    static public func uploadImage(image: UIImage, options: ImageUploadOptions) async throws -> String {
        guard let data = try? image.compressImage(
            compressionQuality: options.compressionQuality,
            imageType: options.type,
            passImagesType: options.passImagesType
        ) else {
            throw UploadError.compressError
        }

        let imageFormat = data.1
        let imageData = data.0
        let imageKey = buildImageKey(with: options)

        do {
            let finalURL = try await awsS3.putObject(
                data: imageData,
                bucket: bucket,
                bucketWithEndpoint: bucketWithEndpoint,
                key: imageKey
            )

            
            return finalURL
        } catch {
            throw UploadError.putObjectError(error.localizedDescription)
        }
    }

    static public func upload(
        images: [UIImage],
        options: ImageUploadOptions
    ) async throws -> [String] {
            var results: [String] = []
            for image in images {
                let url = try await uploadImage(
                    image: image,
                    options: options
                )
                results.append(url)
            }

            return results
    }
    
}

extension AttachmentS3Client {
    public static var live: AttachmentS3Client =
        .init(
            uploadImageToS3: { image, options in
                return try await AttachmentS3Client.uploadImage(
                    image: image,
                    options: options
                )
            },

            uploadImagesToS3: { images, options in
                return try await AttachmentS3Client.upload(images: images, options: options)
            }
        )
}

public enum AttachmentS3ClientKey: TestDependencyKey {
    public static let testValue = AttachmentS3Client.happyPath
}

extension AttachmentS3ClientKey: DependencyKey {
    public static let liveValue: AttachmentS3Client = AttachmentS3Client.live
}

extension DependencyValues {
    public var attachmentS3Client: AttachmentS3Client {
        get { self[AttachmentS3ClientKey.self] }
        set { self[AttachmentS3ClientKey.self] = newValue }
    }
}

extension S3 {

    func putObject(
        data: Data,
        bucket: String,
        bucketWithEndpoint: String,
        key: String
    ) async throws -> String {
        let body = AWSPayload.data(data)
        let putObjectRequest = S3.PutObjectRequest(
            acl: .publicRead,
            body: body,
            bucket: bucket,
            contentLength: Int64(data.count),
            contentType: "image/png",
            key: key
        )

        _ = try await putObject(putObjectRequest)
        
        return bucketWithEndpoint + key
    }
}
