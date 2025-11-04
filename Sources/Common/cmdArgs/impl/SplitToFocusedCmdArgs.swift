public struct SplitToFocusedCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    fileprivate init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .splitToFocused,
        allowInConfig: true,
        help: split_to_focused_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [newArgParser(\.orientation, parseSplitToFocusedArg, mandatoryArgPlaceholder: SplitToFocusedArg.unionLiteral)],
    )

    public var orientation: Lateinit<SplitToFocusedArg> = .uninitialized
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], orientation: SplitToFocusedArg) {
        self.rawArgsForStrRepr = .init(rawArgs.slice)
        self.orientation = .initialized(orientation)
    }
}

public enum SplitToFocusedArg: String, CaseIterable, Sendable {
    case horizontal, vertical, automatic
}

public func parseSplitToFocusedCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SplitToFocusedCmdArgs> {
    parseSpecificCmdArgs(SplitToFocusedCmdArgs(rawArgs: args), args)
}

private func parseSplitToFocusedArg(i: ArgParserInput) -> ParsedCliArgs<SplitToFocusedArg> {
    .init(parseEnum(i.arg, SplitToFocusedArg.self), advanceBy: 1)
}
