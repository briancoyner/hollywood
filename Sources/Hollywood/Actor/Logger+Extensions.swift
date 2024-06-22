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
