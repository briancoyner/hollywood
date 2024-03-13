import OSLog

// MARK: - Logger Convenience

extension Logger {

    init<T>(subject: T) {
        self.init(subsystem: Logger.subsystem, category: "\(type(of: subject.self))")
    }

    private static var subsystem: String {
        return "briancoyner.github.io"
    }
}


// MARK: - Swift 6 Concurrency Workaround

extension Logger: @unchecked Sendable {
    // OSLog/Logger should be marked `Sendable`: 
    // - https://forums.developer.apple.com/forums/thread/747816
}
