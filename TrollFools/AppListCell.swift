//
//  AppListCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import SwiftUI
import CocoaLumberjackSwift

struct AppListCell: View {
    @EnvironmentObject var appList: AppListModel

    @StateObject var app: App

    @available(iOS 15.0, *)
    var highlightedName: AttributedString {
        let name = app.name
        var attributedString = AttributedString(name)
        if let range = attributedString.range(of: appList.filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    @available(iOS 15.0, *)
    var highlightedId: AttributedString {
        let id = app.id
        var attributedString = AttributedString(id)
        if let range = attributedString.range(of: appList.filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    @ViewBuilder
    var cellContextMenu: some View {
        Button {
            launch()
        } label: {
            Label(NSLocalizedString("Launch", comment: ""), systemImage: "command")
        }

        Button {
            openInFilza()
        } label: {
            if isFilzaInstalled {
                Label(NSLocalizedString("Show in Filza", comment: ""), systemImage: "scope")
            } else {
                Label(NSLocalizedString("Filza (URL Scheme) Not Installed", comment: ""), systemImage: "xmark.octagon")
            }
        }
        .disabled(!isFilzaInstalled)

        if AppListModel.hasTrollStore && app.isAllowedToAttachOrDetach {
            if app.isDetached {
                Button {
                    do {
                        _ = try InjectorV3(app.url)
                        try InjectorV3(app.url).setMetadataDetached(false)
                        withAnimation {
                            app.reload()
                            appList.isRebuildNeeded = true
                        }
                    } catch { DDLogError("\(error)", ddlog: InjectorV3.main.logger) }
                } label: {
                    Label(NSLocalizedString("Unlock Version", comment: ""), systemImage: "lock.open")
                }
            } else {
                Button {
                    do {
                        _ = try InjectorV3(app.url)
                        try InjectorV3(app.url).setMetadataDetached(true)
                        withAnimation {
                            app.reload()
                            appList.isRebuildNeeded = true
                        }
                    } catch { DDLogError("\(error)", ddlog: InjectorV3.main.logger) }
                } label: {
                    Label(NSLocalizedString("Lock Version", comment: ""), systemImage: "lock")
                }
            }
            
            Button {
                clearAppCache()
            } label: {
                Label(NSLocalizedString("Clear App Cache", comment: ""), systemImage: "trash")
            }
            Button {
                useLastConfiguration()
            } label: {
                Label(NSLocalizedString("Use Last Configuration", comment: ""), systemImage: "gear")
            }
        }
    }

    @ViewBuilder
    var cellContextMenuWrapper: some View {
        if #available(iOS 16.0, *) {
            // iOS 16
            cellContextMenu
        } else {
            if #available(iOS 15.0, *) { }
            else {
                // iOS 14
                cellContextMenu
            }
        }
    }

    @ViewBuilder
    var cellBackground: some View {
        if #available(iOS 15.0, *) {
            if #available(iOS 16.0, *) { }
            else {
                // iOS 15
                Color.clear
                    .contextMenu {
                        if !appList.isSelectorMode {
                            cellContextMenu
                        }
                    }
                    .id(app.isDetached)
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: app.alternateIcon ?? app.icon ?? UIImage())
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if #available(iOS 15.0, *) {
                        Text(highlightedName)
                            .font(.headline)
                            .lineLimit(1)
                    } else {
                        Text(app.name)
                            .font(.headline)
                            .lineLimit(1)
                    }

                    if app.isInjected {
                        Image(systemName: "bandage")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .accessibilityLabel(NSLocalizedString("Patched", comment: ""))
                    }
                }

                if #available(iOS 15.0, *) {
                    Text(highlightedId)
                        .font(.subheadline)
                        .lineLimit(1)
                } else {
                    Text(app.id)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let version = app.version {
                if app.isUser && app.isDetached {
                    HStack(spacing: 4) {
                        Image(systemName: "lock")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .accessibilityLabel(NSLocalizedString("Pinned Version", comment: ""))

                        Text(version)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(version)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .contextMenu {
            if !appList.isSelectorMode {
                cellContextMenuWrapper
            }
        }
        .background(cellBackground)
    }

    private func launch() {
        LSApplicationWorkspace.default().openApplication(withBundleID: app.id)
    }

    var isFilzaInstalled: Bool { appList.isFilzaInstalled }

    private func openInFilza() {
        appList.openInFilza(app.url)
    }

    private func useLastConfiguration() {
        let alert = UIAlertController(title: NSLocalizedString("Coming Soon", comment: ""), message: NSLocalizedString("This feature is coming soon.", comment: ""), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Confirm", comment: ""), style: .default, handler: nil))
        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            topController.present(alert, animated: true, completion: nil)
        }
    }

    private func clearAppCache() {
        do {
            let injector = try InjectorV3(app.url)
            
            let cachePaths = [
                URL(fileURLWithPath: app.dataurl.path.replacingOccurrences(of: "/private/", with: "")).appendingPathComponent("Library/Caches"),
                URL(fileURLWithPath: app.dataurl.path.replacingOccurrences(of: "/private/", with: "")).appendingPathComponent("tmp")
            ]
            
            for path in cachePaths {
                // DDLogInfo("[AppCache] 正在清理路径: \(path.path)")
                try injector.cmdRemove(path, recursively: true)
            }
            
            // DDLogInfo("[AppCache] 应用缓存清理完成")
        } catch {
            // DDLogInfo("[AppCache] 清理缓存失败: \(error.localizedDescription)")
        }
    }
}
