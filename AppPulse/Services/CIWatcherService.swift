import Foundation

class CIWatcherService {
    var onNewFiles: (([URL]) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1
    private var knownFiles: Set<URL> = []
    private var watchURL: URL?

    var isRunning: Bool { source != nil }

    func start(watching folderURL: URL) {
        stop()

        // Create the folder if it doesn't exist yet
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        watchURL = folderURL
        knownFiles = Set(filesIn(folderURL))

        dirFD = open(folderURL.path, O_EVTONLY)
        guard dirFD >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFD,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )

        source?.setEventHandler { [weak self] in
            guard let self, let url = self.watchURL else { return }
            let current = Set(self.filesIn(url))
            let newFiles = current.subtracting(self.knownFiles)
            self.knownFiles = current
            guard !newFiles.isEmpty else { return }
            DispatchQueue.main.async { self.onNewFiles?(Array(newFiles)) }
        }

        source?.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.dirFD >= 0 { close(self.dirFD); self.dirFD = -1 }
        }

        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        knownFiles = []
        watchURL = nil
    }

    private func filesIn(_ folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )) ?? []
    }
}
