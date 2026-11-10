import Flutter
import UIKit
import UniformTypeIdentifiers

public class PickFilePlugin: NSObject, FlutterPlugin, PickFileHostApi, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {

    private static let cacheSubdir = "pick_file"
    private static let bufferSize = 64 * 1024 // 64 KB

    private var isBusy = false
    private let lock = NSLock()

    private var activeProcessingFiles = Set<String>()
    private let activeFilesLock = NSLock()

    private var continuation: CheckedContinuation<[PickedFileResult], Error>?
    private var currentOptions: FilePickOptionsDto?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PickFilePlugin()
        PickFileHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    }

    // MARK: - PickFileHostApi Implementation

    public func pickFiles(options: FilePickOptionsDto) async throws -> [PickedFileResult] {
        try acquireLock()
        currentOptions = options

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont

            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    cont.resume(throwing: PigeonError(
                        code: "platform_unavailable",
                        message: "Plugin instance was deallocated",
                        details: nil
                    ))
                    return
                }

                guard let topVC = self.topViewController() else {
                    self.releaseLock()
                    self.currentOptions = nil
                    cont.resume(throwing: PigeonError(
                        code: "platform_unavailable",
                        message: "Could not find top UIViewController to present document picker",
                        details: nil
                    ))
                    return
                }

                let contentTypes = self.resolveContentTypes(options: options)
                let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: false)
                picker.allowsMultipleSelection = options.allowMultiple
                picker.delegate = self
                picker.presentationController?.delegate = self

                topVC.present(picker, animated: true, completion: nil)
            }
        }
    }

    public func clearCache() async throws {
        let cacheDir = getCacheDirectory()
        guard let fileUrls = try? FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return
        }

        for fileUrl in fileUrls {
            activeFilesLock.lock()
            let isActive = activeProcessingFiles.contains(fileUrl.path)
            activeFilesLock.unlock()

            if !isActive {
                try? FileManager.default.removeItem(at: fileUrl)
            }
        }
    }

    // MARK: - UIDocumentPickerDelegate

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        let cont = continuation
        continuation = nil
        currentOptions = nil
        releaseLock()
        cont?.resume(returning: [])
    }

    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if continuation != nil {
            documentPickerWasCancelled(presentationController.presentedViewController as! UIDocumentPickerViewController)
        }
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let cont = continuation
        let options = currentOptions
        continuation = nil
        currentOptions = nil

        guard let cont = cont else {
            releaseLock()
            return
        }

        if urls.isEmpty {
            releaseLock()
            cont.resume(returning: [])
            return
        }

        // Validate maxFiles upfront
        if let maxFiles = options?.maxFiles, urls.count > maxFiles {
            releaseLock()
            cont.resume(throwing: PigeonError(
                code: "maximum_file_count_exceeded",
                message: "Selected \(urls.count) files exceeds maximum allowed count of \(maxFiles)",
                details: nil
            ))
            return
        }

        // Offload file copying and streaming to background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                cont.resume(throwing: PigeonError(
                    code: "platform_unavailable",
                    message: "Plugin deallocated during file processing",
                    details: nil
                ))
                return
            }

            var createdUrls: [URL] = []
            var results: [PickedFileResult] = []

            do {
                let cacheDir = self.getCacheDirectory()

                for url in urls {
                    let result = try self.processSingleUrl(
                        url: url,
                        options: options,
                        cacheDir: cacheDir,
                        createdUrls: &createdUrls
                    )
                    results.append(result)
                }

                self.releaseLock()
                cont.resume(returning: results)
            } catch let error as PigeonError {
                self.cleanupBatchFiles(createdUrls)
                self.releaseLock()
                cont.resume(throwing: error)
            } catch {
                self.cleanupBatchFiles(createdUrls)
                self.releaseLock()
                cont.resume(throwing: PigeonError(
                    code: "file_copy_failed",
                    message: "Unexpected error during file processing: \(error.localizedDescription)",
                    details: nil
                ))
            }
        }
    }

    // MARK: - File Processing Helpers

    private func processSingleUrl(
        url: URL,
        options: FilePickOptionsDto?,
        cacheDir: URL,
        createdUrls: inout [URL]
    ) throws -> PickedFileResult {
        let shouldStopAccess = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        var coordinatedError: NSError?
        var processedResult: PickedFileResult?
        var coordinationFailure: Error?

        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinatedError) { coordinatedUrl in
            do {
                let rawDisplayName = coordinatedUrl.lastPathComponent
                let fileExtension = coordinatedUrl.pathExtension.lowercased()
                let mimeType = self.getMimeType(for: coordinatedUrl)
                let displayName = self.sanitizeFileName(rawDisplayName)

                // Validate extension if allowedExtensions is configured
                if let allowedExts = options?.allowedExtensions, !allowedExts.isEmpty {
                    let isAllowed = allowedExts.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == fileExtension }
                    if !isAllowed {
                        throw PigeonError(
                            code: "unsupported_file_type",
                            message: "Selected file '\(displayName)' with extension '.\(fileExtension)' is not allowed",
                            details: nil
                        )
                    }
                }

                // Validate MIME type if allowedMimeTypes is configured
                if let allowedMimes = options?.allowedMimeTypes, !allowedMimes.isEmpty {
                    let normalizedMime = mimeType.lowercased()
                    let isAllowed = allowedMimes.contains { self.mimeMatches(actual: normalizedMime, pattern: $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
                    if !isAllowed {
                        throw PigeonError(
                            code: "unsupported_file_type",
                            message: "Selected file '\(displayName)' with MIME type '\(mimeType)' is not allowed",
                            details: nil
                        )
                    }
                }

                let uniqueName = "\(UUID().uuidString)_\(displayName)"
                let targetUrl = cacheDir.appendingPathComponent(uniqueName)

                self.trackActiveFile(targetUrl.path)
                createdUrls.append(targetUrl)

                let totalWritten = try self.streamCopy(
                    from: coordinatedUrl,
                    to: targetUrl,
                    maxSizeBytes: options?.maxSizeBytes,
                    displayName: displayName
                )

                self.untrackActiveFile(targetUrl.path)

                processedResult = PickedFileResult(
                    path: targetUrl.path,
                    name: displayName,
                    extension: fileExtension,
                    mimeType: mimeType,
                    sizeBytes: totalWritten
                )
            } catch {
                coordinationFailure = error
            }
        }

        if let err = coordinationFailure {
            throw err
        }

        if let err = coordinatedError {
            throw PigeonError(
                code: "provider_unavailable",
                message: "File coordinator failed: \(err.localizedDescription)",
                details: nil
            )
        }

        guard let result = processedResult else {
            throw PigeonError(
                code: "file_read_failed",
                message: "Failed to read file from document provider",
                details: nil
            )
        }

        return result
    }

    private func streamCopy(
        from sourceUrl: URL,
        to targetUrl: URL,
        maxSizeBytes: Int64?,
        displayName: String
    ) throws -> Int64 {
        guard let inputStream = InputStream(url: sourceUrl) else {
            throw PigeonError(
                code: "file_read_failed",
                message: "Could not create input stream for '\(displayName)'",
                details: nil
            )
        }

        guard let outputStream = OutputStream(url: targetUrl, append: false) else {
            throw PigeonError(
                code: "file_copy_failed",
                message: "Could not create destination stream for '\(displayName)'",
                details: nil
            )
        }

        inputStream.open()
        defer { inputStream.close() }

        outputStream.open()
        defer { outputStream.close() }

        var buffer = [UInt8](repeating: 0, count: Self.bufferSize)
        var totalWritten: Int64 = 0

        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&buffer, maxLength: buffer.count)
            if bytesRead < 0 {
                let err = inputStream.streamError
                throw PigeonError(
                    code: "file_read_failed",
                    message: "Stream reading failed for '\(displayName)': \(err?.localizedDescription ?? "unknown")",
                    details: nil
                )
            }
            if bytesRead == 0 {
                break
            }

            totalWritten += Int64(bytesRead)
            if let maxSizeBytes = maxSizeBytes, totalWritten > maxSizeBytes {
                try? FileManager.default.removeItem(at: targetUrl)
                throw PigeonError(
                    code: "maximum_size_exceeded",
                    message: "File '\(displayName)' exceeds maximum size of \(maxSizeBytes) bytes (copied \(totalWritten) bytes)",
                    details: nil
                )
            }

            var bytesWritten = 0
            while bytesWritten < bytesRead {
                let count = buffer.withUnsafeBytes { rawBuffer -> Int in
                    let ptr = rawBuffer.baseAddress!.advanced(by: bytesWritten).assumingMemoryBound(to: UInt8.self)
                    return outputStream.write(ptr, maxLength: bytesRead - bytesWritten)
                }

                if count < 0 {
                    try? FileManager.default.removeItem(at: targetUrl)
                    let err = outputStream.streamError as? NSError
                    if err?.domain == NSPOSIXErrorDomain && err?.code == 28 { // ENOSPC
                        throw PigeonError(
                            code: "insufficient_storage",
                            message: "Device storage is full while writing '\(displayName)'",
                            details: nil
                        )
                    }
                    throw PigeonError(
                        code: "file_copy_failed",
                        message: "Stream write failed for '\(displayName)': \(outputStream.streamError?.localizedDescription ?? "unknown")",
                        details: nil
                    )
                }
                bytesWritten += count
            }
        }

        return totalWritten
    }

    private func cleanupBatchFiles(_ urls: [URL]) {
        for url in urls {
            untrackActiveFile(url.path)
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - UTType & Content Type Resolution

    private func resolveContentTypes(options: FilePickOptionsDto) -> [UTType] {
        let type = options.filterType ?? "any"

        switch type {
        case "images":
            return [.image]
        case "videos":
            return [.movie, .video]
        case "audio":
            return [.audio]
        case "documents":
            var types: [UTType] = [
                .pdf,
                .text,
                .plainText,
                .rtf,
                .spreadsheet,
                .presentation,
                .commaSeparatedText,
                .json,
                .html,
                .xml
            ]
            let documentIdentifiers = [
                "com.microsoft.word.doc",
                "org.openxmlformats.wordprocessingml.document",
                "com.microsoft.excel.xls",
                "org.openxmlformats.spreadsheetml.sheet",
                "com.microsoft.powerpoint.ppt",
                "org.openxmlformats.presentationml.presentation",
                "org.oasis-open.opendocument.text",
                "org.oasis-open.opendocument.spreadsheet",
                "org.oasis-open.opendocument.presentation"
            ]
            for id in documentIdentifiers {
                if let ut = UTType(id) {
                    types.append(ut)
                }
            }
            return types
        case "archives":
            var types: [UTType] = [.archive, .zip, .gzip]
            let archiveIdentifiers = [
                "org.gnu.gnu-zip-archive",
                "org.7-zip.7-zip-archive",
                "com.rarlab.rar-archive",
                "public.tar-archive",
                "public.bzip2-archive",
                "public.xz-archive"
            ]
            for id in archiveIdentifiers {
                if let ut = UTType(id) {
                    types.append(ut)
                }
            }
            return types
        default:
            var types: [UTType] = []

            if let extensions = options.allowedExtensions {
                for ext in extensions {
                    let clean = ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    if !clean.isEmpty {
                        if let ut = UTType(filenameExtension: clean) {
                            types.append(ut)
                        } else {
                            let dynamicUT = UTType(tag: clean, tagClass: .filenameExtension, conformingTo: .data) ?? .item
                            types.append(dynamicUT)
                        }
                    }
                }
            }

            if let mimeTypes = options.allowedMimeTypes {
                for mime in mimeTypes {
                    let clean = mime.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if let ut = UTType(mimeType: clean) {
                        types.append(ut)
                    }
                }
            }

            if types.isEmpty {
                return [.item]
            }
            return types
        }
    }

    private func getMimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if let utType = UTType(filenameExtension: ext), let mime = utType.preferredMIMEType {
            return mime
        }
        switch ext {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt": return "text/plain"
        case "csv": return "text/csv"
        case "json": return "application/json"
        case "zip": return "application/zip"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "mp4": return "video/mp4"
        case "mp3": return "audio/mpeg"
        default: return "application/octet-stream"
        }
    }

    private func mimeMatches(actual: String, pattern: String) -> Bool {
        if pattern == "*/*" || pattern == actual { return true }
        if pattern.hasSuffix("/*") {
            let prefix = pattern.components(separatedBy: "/*").first ?? ""
            return actual.hasPrefix("\(prefix)/")
        }
        return false
    }

    private func sanitizeFileName(_ rawName: String) -> String {
        let base = URL(fileURLWithPath: rawName).lastPathComponent
        let cleaned = base.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
        return (cleaned.isEmpty || cleaned == "." || cleaned == "..") ? "file_\(Int(Date().timeIntervalSince1970))" : cleaned
    }

    private func getCacheDirectory() -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Self.cacheSubdir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        return cacheDir
    }

    private func trackActiveFile(_ path: String) {
        activeFilesLock.lock()
        activeProcessingFiles.insert(path)
        activeFilesLock.unlock()
    }

    private func untrackActiveFile(_ path: String) {
        activeFilesLock.lock()
        activeProcessingFiles.remove(path)
        activeFilesLock.unlock()
    }

    private func acquireLock() throws {
        lock.lock()
        defer { lock.unlock() }
        if isBusy {
            throw PigeonError(code: "picker_busy", message: "Another file picker operation is already in progress", details: nil)
        }
        isBusy = true
    }

    private func releaseLock() {
        lock.lock()
        defer { lock.unlock() }
        isBusy = false
    }

    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = keyWindow.rootViewController else {
            return nil
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}
