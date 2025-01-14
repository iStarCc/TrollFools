//
//  InjectorV3+Preprocess.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import ZIPFoundation
import CocoaLumberjackSwift

extension InjectorV3 {

    // MARK: - Constants

    fileprivate static let allowedPathExtensions: Set<String> = ["bundle", "dylib", "framework"]

    // MARK: - Shared Methods

    func preprocessAssets(_ assetURLs: [URL]) throws -> [URL] {

        DDLogVerbose("Preprocess \(assetURLs.map { $0.path })", ddlog: logger)
        
        var preparedAssetURLs = [URL]()
        var urlsToMarkAsInjected = [URL]()

        for assetURL in assetURLs {

            let lowerExt = assetURL.pathExtension.lowercased()
            if lowerExt == "zip" {
                let extractedURL = temporaryDirectoryURL
                    .appendingPathComponent("\(UUID().uuidString)_\(assetURL.lastPathComponent)")
                    .appendingPathExtension("extracted")

                try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)
                try FileManager.default.unzipItem(at: assetURL, to: extractedURL)

                let extractedItems = try FileManager.default
                    .contentsOfDirectory(at: extractedURL, includingPropertiesForKeys: nil)
                    .filter { Self.allowedPathExtensions.contains($0.pathExtension.lowercased()) }

                for extractedItem in extractedItems {
                    if checkIsBundle(extractedItem) {
                        urlsToMarkAsInjected.append(extractedItem)
                    }
                }

                preparedAssetURLs.append(contentsOf: extractedItems)
                continue
            } else if lowerExt == "deb" {
                let extractedURL = temporaryDirectoryURL
                    .appendingPathComponent("\(UUID().uuidString)_\(assetURL.lastPathComponent)")
                    .appendingPathExtension("extracted")

                try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)
                try _ = decomposeDeb(at: assetURL, to: extractedURL)

                var dylibFiles = [URL]()
                var bundleFiles = [URL]()
                let fileManager = FileManager.default
                let enumerator = fileManager.enumerator(at: extractedURL, includingPropertiesForKeys: nil)

                while let file = enumerator?.nextObject() as? URL {
                    let ext = file.pathExtension.lowercased()
                    if ext == "dylib" || ext == "framework" {
                        dylibFiles.append(file)
                    }
                    if ext == "bundle" {
                        bundleFiles.append(file)
                        urlsToMarkAsInjected.append(file)
                    }
                }

                preparedAssetURLs.append(contentsOf: dylibFiles)
                preparedAssetURLs.append(contentsOf: bundleFiles)
                continue
            }

            else if Self.allowedPathExtensions.contains(lowerExt) {

                let copiedURL = temporaryDirectoryURL
                    .appendingPathComponent(assetURL.lastPathComponent)
                try FileManager.default.copyItem(at: assetURL, to: copiedURL)

                if checkIsBundle(copiedURL) {
                    urlsToMarkAsInjected.append(copiedURL)
                }

                preparedAssetURLs.append(copiedURL)
                continue
            }
        }

        try markBundlesAsInjected(urlsToMarkAsInjected, privileged: false)

        preparedAssetURLs.removeAll(where: { Self.ignoredDylibAndFrameworkNames.contains($0.lastPathComponent) })
        guard !preparedAssetURLs.isEmpty else {
            throw Error.generic(NSLocalizedString("No valid plug-ins found.", comment: ""))
        }

        return preparedAssetURLs
    }
}
