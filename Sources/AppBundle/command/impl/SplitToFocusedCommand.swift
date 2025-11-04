import AppKit
import Common

struct SplitToFocusedCommand: Command {
    let args: SplitToFocusedCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let newWindow = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        guard let referenceWindow = findReferenceWindow(for: newWindow) else {
            return io.err("Can't find a focused window to split with")
        }
        guard let referenceParent = referenceWindow.parent as? TilingContainer else {
            return io.err("Can't split floating windows")
        }
        guard case .tilingContainer = newWindow.parent?.cases else {
            return io.err("Can't slot non-tiling windows")
        }
        guard referenceWindow.visualWorkspace === newWindow.visualWorkspace,
              referenceWindow.visualWorkspace != nil
        else {
            return io.err("Windows belong to different workspaces")
        }

        let orientation = try await resolveOrientation(parent: referenceParent, referenceWindow: referenceWindow)

        let referenceIndex = referenceWindow.ownIndex.orDie()
        let isTargetBeforeReference = (newWindow.parent as? TilingContainer) === referenceParent &&
            (newWindow.ownIndex.orDie() < referenceIndex)

        let referenceBinding = referenceWindow.unbindFromParent()
        let targetBinding = newWindow.unbindFromParent()

        let container = TilingContainer(
            parent: referenceBinding.parent,
            adaptiveWeight: referenceBinding.adaptiveWeight,
            orientation,
            .tiles,
            index: referenceBinding.index,
        )

        if isTargetBeforeReference {
            newWindow.bind(to: container, adaptiveWeight: WEIGHT_AUTO, index: 0)
            referenceWindow.bind(to: container, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        } else {
            referenceWindow.bind(to: container, adaptiveWeight: WEIGHT_AUTO, index: 0)
            newWindow.bind(to: container, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }

        // Clean up the previous parent if it became empty (e.g. target window was the only child)
        if let previousParent = targetBinding.parent as? TilingContainer,
           previousParent.children.isEmpty,
           previousParent !== container
        {
            previousParent.unbindFromParent()
        }

        container.changeOrientation(orientation)
        return true
    }

    @MainActor
    private func findReferenceWindow(for window: Window) -> Window? {
        if let currentFocus = focus.windowOrNil, currentFocus !== window {
            return currentFocus
        }
        if let previousFocus = prevFocus?.windowOrNil, previousFocus !== window {
            return previousFocus
        }
        if let parent = window.parent as? TilingContainer {
            return parent.children.compactMap { $0 as? Window }.first(where: { $0 !== window })
        }
        return window.visualWorkspace?.allLeafWindowsRecursive.first(where: { $0 !== window })
    }

    private func resolveOrientation(parent: TilingContainer, referenceWindow: Window) async throws -> Orientation {
        switch args.orientation.val {
            case .horizontal:
                return .h
            case .vertical:
                return .v
            case .automatic:
                if let rect = referenceWindow.lastAppliedLayoutPhysicalRect ?? referenceWindow.lastAppliedLayoutVirtualRect {
                    return rect.width >= rect.height ? .h : .v
                }
                if let size = try? await referenceWindow.getAxSize() {
                    return size.width >= size.height ? .h : .v
                }
                return parent.orientation
        }
    }
}
