//
//  EjectListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/20.
//

import SwiftUI
import ZIPFoundation
import UniformTypeIdentifiers

struct EjectListView: View {
    @StateObject var ejectList: EjectListModel

    init(_ app: App) {
        _ejectList = StateObject(wrappedValue: EjectListModel(app))
    }

    @State var isErrorOccurred: Bool = false
    @State var errorMessage: String = ""

    @State var isDeletingAll = false
    @StateObject var viewControllerHost = ViewControllerHost()

    @State private var isExporting = false
    @State private var exportURL: URL?

    var deleteAllButtonLabel: some View {
        HStack {
            Label(NSLocalizedString("Eject All", comment: ""), systemImage: "eject")
            Spacer()
            if isDeletingAll {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }

    var deleteAllButton: some View {
        if #available(iOS 15.0, *) {
            Button(role: .destructive) {
                deleteAll()
            } label: {
                deleteAllButtonLabel
            }
        } else {
            Button {
                deleteAll()
            } label: {
                deleteAllButtonLabel
            }
        }
    }

    var ejectListView: some View {
        List {
            Section {
                ForEach(ejectList.filteredPlugIns) { plugin in
                    if #available(iOS 16.0, *) {
                        PlugInCell(plugIn: plugin)
                            .environmentObject(ejectList)
                    } else {
                        // let _ = NSLog("[EjectListView] 插件: \(plugin.url.path), \(ejectList.app.name)")
                        PlugInCell(plugIn: plugin)
                            .environmentObject(ejectList)
                            .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: delete)
            } header: {
                Text(ejectList.filteredPlugIns.isEmpty
                     ? NSLocalizedString("No Injected Plug-Ins", comment: "")
                     : NSLocalizedString("Injected Plug-Ins", comment: ""))
                    .font(.footnote)
            }

            if !ejectList.filter.isSearching && !ejectList.filteredPlugIns.isEmpty {
                Section {
                    deleteAllButton
                        .disabled(isDeletingAll)
                        .foregroundColor(isDeletingAll ? .secondary : .red)
                } footer: {
                    if ejectList.app.isFromTroll {
                        Text(NSLocalizedString("Some plug-ins were not injected by TrollFools, please eject them with caution.", comment: ""))
                            .font(.footnote)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Plug-Ins", comment: ""))
        .animation(.easeOut, value: ejectList.filter.isSearching)
        .background(Group {
            NavigationLink(isActive: $isErrorOccurred) {
                FailureView(title: NSLocalizedString("Error", comment: ""),
                            message: errorMessage)
            } label: { }
        })
        .onViewWillAppear { viewController in
            viewControllerHost.viewController = viewController
        }
    }

    var exportButton: some View {
        Button(action: {
            Task {
                await exportPlugIns()
            }
        }) {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(ejectList.filteredPlugIns.isEmpty)
    }

    func exportPlugIns() async {
        guard !ejectList.filteredPlugIns.isEmpty else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let zipFileName = "\(ejectList.app.name)Plugins_\(timestamp)"
        let zipFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(zipFileName).zip")

        do {
            let fileManager = FileManager.default
            let archive = try Archive(url: zipFileURL, accessMode: .create)

            for plugin in ejectList.filteredPlugIns {
                let entryPath = "\(plugin.url.lastPathComponent)"
                
                guard fileManager.fileExists(atPath: plugin.url.path) else {
                    NSLog("File not found: \(plugin.url.path)")
                    continue
                }
                
                try archive.addEntry(
                    with: entryPath, 
                    fileURL: plugin.url, 
                    compressionMethod: .deflate
                )
            }

            await MainActor.run {
                shareFile(zipFileURL)
            }
        } catch {
            NSLog("Export error: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isErrorOccurred = true
            }
        }
    }

    private func shareFile(_ fileURL: URL) {
        guard let viewController = viewControllerHost.viewController else { return }
        
        DispatchQueue.main.async {
            let activityController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            if #available(iOS 15.0, *) {
                activityController.modalPresentationStyle = .pageSheet
                if let sheet = activityController.sheetPresentationController {
                    sheet.detents = [.medium()]
                    sheet.prefersGrabberVisible = true
                }
            } else {
                activityController.modalPresentationStyle = .formSheet
            }
            
            activityController.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in}
            
            viewController.present(activityController, animated: true)
        }
    }

    var body: some View {
        if #available(iOS 15.0, *) {
            ejectListView
                .refreshable {
                    withAnimation {
                        ejectList.reload()
                    }
                }
                .searchable(
                    text: $ejectList.filter.searchKeyword,
                    placement: .automatic,
                    prompt: NSLocalizedString("Search…", comment: "")
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        exportButton
                    }
                }
        } else {
            ejectListView
                .navigationBarItems(trailing: exportButton)
        }
    }

    func delete(at offsets: IndexSet) {
        do {
            let plugInsToRemove = offsets.map { ejectList.filteredPlugIns[$0] }
            let plugInURLsToRemove = plugInsToRemove.map { $0.url }
            try InjectorV3(ejectList.app.url).eject(plugInURLsToRemove)

            ejectList.app.reload()
            ejectList.reload()
        } catch {
            NSLog("\(error)")

            errorMessage = error.localizedDescription
            isErrorOccurred = true
        }
    }

    func deleteAll() {
        do {
            let injector = try InjectorV3(ejectList.app.url)

            let view = viewControllerHost.viewController?
                .navigationController?.view

            view?.isUserInteractionEnabled = false

            withAnimation {
                isDeletingAll = true
            }

            DispatchQueue.global(qos: .userInteractive).async {
                defer {
                    DispatchQueue.main.async {
                        withAnimation {
                            ejectList.app.reload()
                            ejectList.reload()
                            isDeletingAll = false
                        }

                        view?.isUserInteractionEnabled = true
                    }
                }

                do {
                    try injector.ejectAll()
                } catch {
                    DispatchQueue.main.async {
                        withAnimation {
                            isDeletingAll = false
                        }

                        NSLog("\(error)")

                        errorMessage = error.localizedDescription
                        isErrorOccurred = true
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isErrorOccurred = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        if #available(iOS 15.0, *) {
            if let sheet = controller.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {}
}

