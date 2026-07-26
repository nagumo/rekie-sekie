import AppKit
import KeyboardShortcuts
import Sparkle
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private let popover = NSPopover()
    private let snippetPopover = NSPopover()
    private var anchorWindow: NSWindow?
    private var snippetAnchorWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var snippetManagementWindow: NSWindow?
    private var previousApp: NSRunningApplication?
    private let selectionState = SelectionState()
    private let snippetSelectionState = SelectionState()
    private let storage: Storage = {
        do {
            return try Storage()
        } catch {
            fatalError("ストレージの初期化に失敗しました: \(error)")
        }
    }()
    private lazy var monitor = ClipboardMonitor(storage: storage)
    private lazy var snippetManager = SnippetManager(storage: storage)

    private func makeStatusItemIcon() -> NSImage? {
        let icon = NSImage(systemSymbolName: Preferences.menuBarIconName, accessibilityDescription: "rekie-sekie")
        icon?.isTemplate = true
        return icon
    }

    /// 設定画面でメニューバーアイコンを変更したときに呼ぶ。
    private func updateMenuBarIcon() {
        statusItem?.button?.image = makeStatusItemIcon()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = makeStatusItemIcon()
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.target = self
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(monitor: monitor, selectionState: selectionState, onSelect: { [weak self] item in
                self?.paste(item)
            })
        )
        popover.delegate = self

        snippetPopover.behavior = .transient
        snippetPopover.animates = false
        snippetPopover.contentSize = NSSize(width: 320, height: 400)
        snippetPopover.contentViewController = NSHostingController(
            rootView: SnippetsView(
                snippetManager: snippetManager,
                selectionState: snippetSelectionState,
                onSelect: { [weak self] snippet in
                    self?.pasteSnippet(snippet)
                }
            )
        )
        snippetPopover.delegate = self

        monitor.start()
        PasteSimulator.ensureAccessibilityPermission()

        KeyboardShortcuts.onKeyUp(for: .togglePopover) { [weak self] in
            self?.togglePopoverAtMouseLocation()
        }

        KeyboardShortcuts.onKeyUp(for: .toggleSnippets) { [weak self] in
            self?.toggleSnippetsPopoverAtMouseLocation()
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }

        // ポップオーバー表示中に、ポップオーバー外（他アプリ・デスクトップ）をクリックしたら閉じる
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            if self.popover.isShown { self.closePopover() }
            if self.snippetPopover.isShown { self.closeSnippetPopover() }
        }
    }

    /// Escapeキーでポップオーバー・設定ウィンドウを閉じる。それ以外は履歴側のキー操作へ委譲する。
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 { // Escape
            if popover.isShown {
                closePopover()
                return nil
            }
            if snippetPopover.isShown {
                closeSnippetPopover()
                return nil
            }
            if let settingsWindow, settingsWindow.isVisible {
                settingsWindow.close()
                return nil
            }
            if let snippetManagementWindow, snippetManagementWindow.isVisible {
                snippetManagementWindow.close()
                return nil
            }
            return event
        }

        return handlePopoverKeyDown(event)
    }

    /// ポップオーバー表示中のキー操作(数字/矢印/Enter)をクリックと同じ動作にマッピングする。
    private func handlePopoverKeyDown(_ event: NSEvent) -> NSEvent? {
        if popover.isShown {
            let items = monitor.filteredItems(matching: selectionState.searchText)
            return handleListKeyDown(
                event,
                itemCount: items.count,
                selectionState: selectionState,
                select: { [weak self] index in self?.paste(items[index]) }
            )
        }

        if snippetPopover.isShown {
            let items = snippetManager.displayOrder
            return handleListKeyDown(
                event,
                itemCount: items.count,
                selectionState: snippetSelectionState,
                select: { [weak self] index in self?.pasteSnippet(items[index]) }
            )
        }

        return event
    }

    /// 番号(1-9)・矢印キー・Enterでの選択操作を、履歴/スニペット両ポップオーバーで共通化する。
    private func handleListKeyDown(
        _ event: NSEvent,
        itemCount: Int,
        selectionState: SelectionState,
        select: (Int) -> Void
    ) -> NSEvent? {
        guard itemCount > 0 else { return event }

        switch event.keyCode {
        case 125: // Down
            selectionState.selectedIndex = min(selectionState.selectedIndex + 1, itemCount - 1)
            return nil
        case 126: // Up
            selectionState.selectedIndex = max(selectionState.selectedIndex - 1, 0)
            return nil
        case 36, 76: // Return, keypad Enter
            guard (0..<itemCount).contains(selectionState.selectedIndex) else { return event }
            select(selectionState.selectedIndex)
            return nil
        default:
            break
        }

        // 検索欄にフォーカスがある間は数字も検索文字として入力させたいので、クイック選択には使わない
        if !selectionState.isSearchFieldFocused,
           let characters = event.charactersIgnoringModifiers,
           let digit = Int(characters), (1...9).contains(digit) {
            let index = digit - 1
            guard index < itemCount else { return event }
            select(index)
            return nil
        }

        return event
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(for: sender)
            return
        }

        if popover.isShown {
            closePopover()
        } else {
            previousApp = NSWorkspace.shared.frontmostApplication
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu(for sender: NSStatusBarButton) {
        let menu = NSMenu()

        let currentBundle = LocalizationManager.shared.bundle
        let settingsTitle = String(localized: "ショートカット設定...", bundle: currentBundle)
        let settingsItem = NSMenuItem(title: settingsTitle, action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let snippetsTitle = String(localized: "スニペット管理...", bundle: currentBundle)
        let snippetsItem = NSMenuItem(title: snippetsTitle, action: #selector(openSnippetManagement), keyEquivalent: "")
        snippetsItem.target = self
        menu.addItem(snippetsItem)

        menu.addItem(.separator())

        let checkForUpdatesTitle = String(localized: "アップデートを確認...", bundle: currentBundle)
        let checkForUpdatesItem = NSMenuItem(
            title: checkForUpdatesTitle,
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)

        menu.addItem(.separator())

        let quitTitle = String(localized: "終了", bundle: currentBundle)
        let quitItem = NSMenuItem(title: quitTitle, action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        guard let event = NSApp.currentEvent else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: sender)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView(
                onMaxItemsChanged: { [weak self] newValue in
                    self?.monitor.updateMaxItems(newValue)
                },
                onMenuBarIconChanged: { [weak self] in
                    self?.updateMenuBarIcon()
                },
                onClose: { [weak self] in
                    self?.settingsWindow?.close()
                }
            )
        )
        // 指定しないとウィンドウがSwiftUI側の実サイズより先に確定してしまい、余白ごと詰まって表示される
        hostingController.sizingOptions = [.preferredContentSize]
        let window = BorderlessKeyWindow(contentViewController: hostingController)
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSnippetManagement() {
        if let window = snippetManagementWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SnippetManagementView(
                snippetManager: snippetManager,
                onClose: { [weak self] in
                    self?.snippetManagementWindow?.close()
                }
            )
        )
        hostingController.sizingOptions = [.preferredContentSize]
        let window = BorderlessKeyWindow(contentViewController: hostingController)
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()
        snippetManagementWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func togglePopoverAtMouseLocation() {
        if popover.isShown {
            closePopover()
        } else {
            previousApp = NSWorkspace.shared.frontmostApplication
            showPopoverAtMouseLocation()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func paste(_ item: ClipItem) {
        monitor.selectItem(item)
        closePopover()

        guard let previousApp else { return }
        previousApp.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PasteSimulator.sendCommandV()
        }
    }

    private func toggleSnippetsPopoverAtMouseLocation() {
        if snippetPopover.isShown {
            closeSnippetPopover()
        } else {
            previousApp = NSWorkspace.shared.frontmostApplication
            showSnippetPopoverAtMouseLocation()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func pasteSnippet(_ snippet: Snippet) {
        let expanded = snippetManager.expandedContent(for: snippet)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(expanded, forType: .string)
        closeSnippetPopover()

        guard let previousApp else { return }
        previousApp.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PasteSimulator.sendCommandV()
        }
    }

    private func showSnippetPopoverAtMouseLocation() {
        let mouseLocation = NSEvent.mouseLocation
        let anchorRect = NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)

        let window = NSWindow(
            contentRect: anchorRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .popUpMenu
        window.orderFrontRegardless()
        snippetAnchorWindow = window

        guard let contentView = window.contentView else { return }
        snippetPopover.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
    }

    private func closeSnippetPopover() {
        snippetPopover.performClose(nil)
    }

    private func showPopoverAtMouseLocation() {
        let mouseLocation = NSEvent.mouseLocation
        let anchorRect = NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)

        let window = NSWindow(
            contentRect: anchorRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .popUpMenu
        window.orderFrontRegardless()
        anchorWindow = window

        guard let contentView = window.contentView else { return }
        popover.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    func popoverWillShow(_ notification: Notification) {
        guard let shownPopover = notification.object as? NSPopover else { return }
        if shownPopover === snippetPopover {
            snippetSelectionState.selectedIndex = 0
        } else if shownPopover === popover {
            selectionState.selectedIndex = 0
            selectionState.searchText = ""
        }
    }

    func popoverDidClose(_ notification: Notification) {
        guard let closedPopover = notification.object as? NSPopover else { return }
        if closedPopover === snippetPopover {
            snippetAnchorWindow?.close()
            snippetAnchorWindow = nil
        } else {
            anchorWindow?.close()
            anchorWindow = nil
        }
    }
}
