public struct Error: ErrorProtocol {
    let description: String
    public init(_ description: String) {
        self.description = description
    }
}

