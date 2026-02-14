import AppKit

final class BolderAppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: MainWindow?
    private var stripModel: StripModel!
    private var projectStore: ProjectStore?
    private var settingsWindow: SettingsWindow?
    private var projectURL: URL!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // Register custom fonts
        FontLoader.registerFonts()

        // Initialize terminal backend
        GhosttyBridge.shared.initialize()

        let projectPath: String
        if CommandLine.arguments.count > 1 {
            projectPath = CommandLine.arguments[1]
        } else {
            projectPath = FileManager.default.currentDirectoryPath
        }

        let resolvedPath = (projectPath as NSString).standardizingPath
        projectURL = URL(fileURLWithPath: resolvedPath, isDirectory: true)

        let store = ProjectStore(projectURL: projectURL)
        self.projectStore = store

        // Load settings before creating the window
        SettingsManager.shared.load(projectURL: projectURL)

        if let loaded = store.load() {
            self.stripModel = loaded
        } else {
            self.stripModel = StripModel.defaultModel()
        }

        buildMainMenu()

        let window = MainWindow(stripModel: stripModel, projectStore: store)
        window.makeKeyAndOrderFront(nil)
        self.mainWindow = window

        NSApp.activate(ignoringOtherApps: true)

        // Rebuild menus when settings change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: SettingsManager.settingsDidChangeNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let store = projectStore {
            store.save(stripModel)
        }
        TerminalSessionManager.shared.destroyAll()
        GhosttyBridge.shared.shutdown()
    }

    // MARK: - Menu bar

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Bolder", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.items.last?.keyEquivalentModifierMask = .command
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Bolder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        addShortcutItem(to: viewMenu, action: .toggleFullscreen, selector: #selector(StripView.menuToggleFullscreen(_:)))
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Tiles menu
        let tilesMenuItem = NSMenuItem()
        let tilesMenu = NSMenu(title: "Tiles")
        addShortcutItem(to: tilesMenu, action: .focusLeft, selector: #selector(StripView.menuFocusLeft(_:)))
        addShortcutItem(to: tilesMenu, action: .focusRight, selector: #selector(StripView.menuFocusRight(_:)))
        tilesMenu.addItem(.separator())
        addShortcutItem(to: tilesMenu, action: .moveTileLeft, selector: #selector(StripView.menuMoveTileLeft(_:)))
        addShortcutItem(to: tilesMenu, action: .moveTileRight, selector: #selector(StripView.menuMoveTileRight(_:)))
        tilesMenu.addItem(.separator())
        addShortcutItem(to: tilesMenu, action: .shrinkTile, selector: #selector(StripView.menuShrinkTile(_:)))
        addShortcutItem(to: tilesMenu, action: .growTile, selector: #selector(StripView.menuGrowTile(_:)))
        addShortcutItem(to: tilesMenu, action: .toggleFullWidth, selector: #selector(StripView.menuToggleFullWidth(_:)))
        tilesMenu.addItem(.separator())
        addShortcutItem(to: tilesMenu, action: .addNotesTile, selector: #selector(StripView.menuAddNotesTile(_:)))
        addShortcutItem(to: tilesMenu, action: .addTerminalTile, selector: #selector(StripView.menuAddTerminalTile(_:)))
        addShortcutItem(to: tilesMenu, action: .addClaudeTile, selector: #selector(StripView.menuAddClaudeTile(_:)))
        addShortcutItem(to: tilesMenu, action: .addFeaturesTile, selector: #selector(StripView.menuAddFeaturesTile(_:)))
        tilesMenu.addItem(.separator())
        addShortcutItem(to: tilesMenu, action: .refineNote, selector: #selector(StripView.menuRefineNote(_:)))
        addShortcutItem(to: tilesMenu, action: .saveAsFeature, selector: #selector(StripView.menuSaveAsFeature(_:)))
        tilesMenu.addItem(.separator())
        addShortcutItem(to: tilesMenu, action: .removeTile, selector: #selector(StripView.menuRemoveTile(_:)))
        tilesMenuItem.submenu = tilesMenu
        mainMenu.addItem(tilesMenuItem)

        // View menu — font size items
        viewMenu.addItem(.separator())
        addShortcutItem(to: viewMenu, action: .fontSizeUp, selector: #selector(StripView.menuFontSizeUp(_:)))
        addShortcutItem(to: viewMenu, action: .fontSizeDown, selector: #selector(StripView.menuFontSizeDown(_:)))

        NSApp.mainMenu = mainMenu
    }

    private func addShortcutItem(to menu: NSMenu, action: ShortcutAction, selector: Selector) {
        guard let binding = SettingsManager.shared.shortcuts[action] else { return }
        let (equiv, modifiers) = binding.menuKeyEquivalent
        let item = NSMenuItem(title: action.displayName, action: selector, keyEquivalent: equiv)
        item.keyEquivalentModifierMask = modifiers
        menu.addItem(item)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(projectURL: projectURL)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func settingsDidChange() {
        buildMainMenu()
    }
}
