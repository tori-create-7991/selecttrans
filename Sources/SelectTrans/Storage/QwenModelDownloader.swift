import CryptoKit
import Foundation

@MainActor
final class QwenModelDownloader: ObservableObject {
    enum State: Equatable {
        case idle, downloading(String, Int, Int), ready, failed(String)
    }

    @Published private(set) var state: State = .idle

    private let repository = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
    private let fileManager = FileManager.default
    private static let requiredFileNames = ["config.json", "tokenizer.json", "tokenizer_config.json", "model.safetensors"]

    func download() {
        if case .downloading = state { return }
        Task { await performDownload() }
    }

    private func performDownload() async {
        do {
            let manifest = try await fetchManifest()
            let files = manifest.siblings.filter { Self.requiredFileNames.contains($0.rfilename) }
            guard Set(files.map(\.rfilename)) == Set(Self.requiredFileNames),
                  let modelFile = files.first(where: { $0.rfilename == "model.safetensors" }),
                  modelFile.lfs?.size != nil,
                  modelFile.lfs.flatMap({ Self.sha256Digest($0.sha256) }) != nil else {
                throw DownloadError.invalidManifest
            }
            let needed = modelFile.lfs!.size * 2
            let baseDirectory = downloadBaseDirectory()
            let accessed = baseDirectory.startAccessingSecurityScopedResource()
            defer { if accessed { baseDirectory.stopAccessingSecurityScopedResource() } }
            let root = baseDirectory.appendingPathComponent("Qwen2.5-1.5B-Instruct-4bit", isDirectory: true)
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            let capacity = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
            guard capacity > needed else { throw DownloadError.insufficientStorage }

            let destination = root.appendingPathComponent(manifest.sha, isDirectory: true)
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for (index, file) in files.enumerated() {
                state = .downloading(file.rfilename, index + 1, files.count)
                let destinationFile = destination.appendingPathComponent(file.rfilename)
                try await download(file: file, revision: manifest.sha, to: destinationFile)
            }
            try LocalModelStore().setQwenModelURL(destination)
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func fetchManifest() async throws -> Manifest {
        let url = URL(string: "https://huggingface.co/api/models/\(repository)?blobs=true")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DownloadError.requestFailed }
        return try JSONDecoder().decode(Manifest.self, from: data)
    }

    private func download(file: Manifest.File, revision: String, to destination: URL) async throws {
        let temporary = destination.appendingPathExtension("partial")
        var existing = (try? temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        if let expectedSize = file.lfs?.size {
            if existing == expectedSize {
                do {
                    try await verify(file: file, at: temporary)
                } catch {
                    try? fileManager.removeItem(at: temporary)
                    throw error
                }
                try? fileManager.removeItem(at: destination)
                try fileManager.moveItem(at: temporary, to: destination)
                return
            }
            if existing > expectedSize {
                try fileManager.removeItem(at: temporary)
                existing = 0
            }
        }
        let url = URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(file.rfilename)")!
        var request = URLRequest(url: url)
        if existing > 0 { request.setValue("bytes=\(existing)-", forHTTPHeaderField: "Range") }
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw DownloadError.requestFailed }
        if http.statusCode == 416, existing > 0 {
            try? fileManager.removeItem(at: temporary)
            try await download(file: file, revision: revision, to: destination)
            return
        }
        guard http.statusCode == 200 || http.statusCode == 206 else { throw DownloadError.requestFailed }
        if http.statusCode == 206,
           http.value(forHTTPHeaderField: "Content-Range")?.hasPrefix("bytes \(existing)-") != true {
            throw DownloadError.requestFailed
        }
        if existing == 0 { fileManager.createFile(atPath: temporary.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: temporary)
        defer { try? handle.close() }
        if existing > 0, http.statusCode == 200 {
            // The server ignored Range; replace the partial file with its full response.
            try handle.truncate(atOffset: 0)
            try handle.seek(toOffset: 0)
        } else {
            try handle.seekToEnd()
        }
        var buffer = [UInt8]()
        buffer.reserveCapacity(65_536)
        do {
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count == buffer.capacity {
                    try handle.write(contentsOf: Data(buffer))
                    buffer.removeAll(keepingCapacity: true)
                }
            }
            if !buffer.isEmpty { try handle.write(contentsOf: Data(buffer)) }
        } catch {
            // Keep partial bytes so the next explicit download can resume with Range.
            throw error
        }
        do {
            try await verify(file: file, at: temporary)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: temporary, to: destination)
    }

    static let defaultDownloadDirectory: URL = {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let newDir = supportDir.appendingPathComponent("SelectTrans/Models", isDirectory: true)
        LegacyStorageMigration.moveDirectoryIfNeeded(
            legacy: supportDir.appendingPathComponent("NaniMini/Models", isDirectory: true),
            to: newDir
        )
        return newDir
    }()

    private func downloadBaseDirectory() -> URL {
        LocalModelStore().qwenDownloadDirectory ?? Self.defaultDownloadDirectory
    }

    nonisolated static func sha256Digest(_ hash: String) -> String? {
        let value: Substring
        if hash.hasPrefix("sha256:") {
            value = hash.dropFirst("sha256:".count)
        } else {
            value = Substring(hash)
        }
        guard value.count == 64,
              value.allSatisfy({ $0.isHexDigit }) else { return nil }
        return value.lowercased()
    }

    private func verify(file: Manifest.File, at fileURL: URL) async throws {
        guard let lfs = file.lfs else { return }
        guard let expected = Self.sha256Digest(lfs.sha256) else {
            throw DownloadError.integrityFailed(file.rfilename)
        }
        let actual = try await Task.detached {
            try Self.sha256(of: fileURL)
        }.value
        guard actual == expected else { throw DownloadError.integrityFailed(file.rfilename) }
    }

    nonisolated private static func sha256(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private struct Manifest: Decodable {
        let sha: String
        let siblings: [File]
        struct File: Decodable {
            let rfilename: String
            let lfs: LFS?
            struct LFS: Decodable { let sha256: String; let size: Int64 }
        }
    }

    private enum DownloadError: LocalizedError {
        case invalidManifest, insufficientStorage, requestFailed, integrityFailed(String)
        var errorDescription: String? {
            switch self {
            case .invalidManifest: "Qwenの配布ファイルを確認できません。"
            case .insufficientStorage: "Qwenのダウンロードには2GB以上の空き容量が必要です。"
            case .requestFailed: "Qwenモデルのダウンロードに失敗しました。"
            case .integrityFailed(let file): "Qwenファイルの検証に失敗しました: \(file)"
            }
        }
    }
}
