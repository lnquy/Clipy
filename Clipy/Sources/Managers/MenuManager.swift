//
//  MenuManager.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/03/08.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import PINCache
import RealmSwift
import RxCocoa
import RxSwift

final class MenuManager: NSObject {

    // MARK: - Properties
    // Menu view
    fileprivate var globalMenuView: NSMenu?
    fileprivate var lastDisplayedMenuType: MenuType?

    // Menus
    fileprivate var clipMenu: NSMenu?
    fileprivate var historyMenu: NSMenu?
    fileprivate var snippetMenu: NSMenu?
    // StatusMenu
    fileprivate var statusItem: NSStatusItem?
    // Icon Cache
    fileprivate let folderIcon = Asset.iconFolder.image
    fileprivate let snippetIcon = Asset.iconText.image
    // Other
    fileprivate let disposeBag = DisposeBag()
    fileprivate let notificationCenter = NotificationCenter.default
    fileprivate let kMaxKeyEquivalents = 10
    fileprivate let shortenSymbol = "..."
    // Realm
    fileprivate let realm = try! Realm()
    fileprivate var clipToken: NotificationToken?
    fileprivate var snippetToken: NotificationToken?

    // MARK: - Enum Values
    enum StatusType: Int {
        case none, black, white
    }

    // MARK: - Initialize
    override init() {
        super.init()
        folderIcon.isTemplate = true
        folderIcon.size = NSSize(width: 15, height: 13)
        snippetIcon.isTemplate = true
        snippetIcon.size = NSSize(width: 12, height: 13)
    }

    func setup() {
        bind()
    }

}

// MARK: - Popup Menu
extension MenuManager {
    func popUpMenu(_ type: MenuType) {
        switch type {
        case .main:
            self.globalMenuView = buildMenuViewsOnFirstPaint(menuType: .main)
        case .history:
            self.globalMenuView = buildMenuViewsOnFirstPaint(menuType: .history)
        case .snippet:
            self.globalMenuView = buildMenuViewsOnFirstPaint(menuType: .snippet)
        }

        self.lastDisplayedMenuType = type
        self.globalMenuView!.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func popUpSnippetFolder(_ folder: CPYFolder) {
        let folderMenu = NSMenu(title: folder.title)
        // Folder title
        let labelItem = NSMenuItem(title: folder.title, action: nil)
        labelItem.isEnabled = false
        folderMenu.addItem(labelItem)
        // Snippets
        var index = firstIndexOfMenuItems()
        folder.snippets
            .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
            .filter { $0.enable }
            .forEach { snippet in
                let subMenuItem = makeSnippetMenuItem(
                    snippet, listNumber: index)
                folderMenu.addItem(subMenuItem)
                index += 1
            }
        folderMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

// MARK: - Binding
extension MenuManager {
    fileprivate func bind() {
        // Realm Notification
        // TODO[q]: Observe

        //        clipToken = realm.objects(CPYClip.self)
        //            .observe { [weak self] _ in
        //                DispatchQueue.main.async { [weak self] in
        //                    self?.createClipMenu()
        //                }
        //            }

        //        snippetToken = realm.objects(CPYFolder.self)
        //            .observe { [weak self] _ in
        //                DispatchQueue.main.async { [weak self] in
        //                    self?.createClipMenu()
        //                }
        //            }

        // Menu icon
        AppEnvironment.current.defaults.rx.observe(
            Int.self, Constants.UserDefaults.showStatusItem, retainSelf: false
        )
        .compactMap { $0 }
        .asDriver(onErrorDriveWith: .empty())
        .drive(onNext: { [weak self] key in
            self?.changeStatusItem(StatusType(rawValue: key) ?? .black)
        })
        .disposed(by: disposeBag)

        //        // Sort clips
        //        AppEnvironment.current.defaults.rx.observe(
        //            Bool.self, Constants.UserDefaults.reorderClipsAfterPasting,
        //            options: [.new], retainSelf: false
        //        )
        //        .compactMap { $0 }
        //        .asDriver(onErrorDriveWith: .empty())
        //        .drive(onNext: { [weak self] _ in
        //            guard let wSelf = self else { return }
        //            wSelf.createClipMenu()
        //        })
        //        .disposed(by: disposeBag)
        //
        //        // Edit snippets
        //        notificationCenter.rx.notification(
        //            Notification.Name(
        //                rawValue: Constants.Notification.closeSnippetEditor)
        //        )
        //        .asDriver(onErrorDriveWith: .empty())
        //        .drive(onNext: { [weak self] _ in
        //            self?.createClipMenu()
        //        })
        //        .disposed(by: disposeBag)

        // Search updated
        notificationCenter.rx
            .notification(
                Notification
                    .Name(rawValue: Constants.Notification.searchTextUpdated)
            )
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] noti in
                if let searchText = noti.object as? String {
                    self?.refreshMenuViewsOnSearch(searchText: searchText)
                }
            })
            .disposed(by: disposeBag)

        // Observe change preference settings
        let defaults = AppEnvironment.current.defaults
        var menuChangedObservables = [Observable<Void>]()
        menuChangedObservables.append(
            defaults.rx.observe(
                Bool.self, Constants.UserDefaults.addClearHistoryMenuItem,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Int.self, Constants.UserDefaults.maxHistorySize,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Bool.self, Constants.UserDefaults.showIconInTheMenu,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Int.self, Constants.UserDefaults.numberOfItemsPlaceInline,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Int.self, Constants.UserDefaults.numberOfItemsPlaceInsideFolder,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Int.self, Constants.UserDefaults.maxMenuItemTitleLength,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Bool.self, Constants.UserDefaults.menuItemsTitleStartWithZero,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Bool.self, Constants.UserDefaults.menuItemsAreMarkedWithNumbers,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Bool.self, Constants.UserDefaults.showToolTipOnMenuItem,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Bool.self, Constants.UserDefaults.showImageInTheMenu,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Bool.self, Constants.UserDefaults.addNumericKeyEquivalents,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Int.self, Constants.UserDefaults.maxLengthOfToolTip,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(
            defaults.rx.observe(
                Bool.self, Constants.UserDefaults.showColorPreviewInTheMenu,
                options: [.new], retainSelf: false
            )
            .compactMap { $0 }.distinctUntilChanged().map { _ in })

        //        Observable.merge(menuChangedObservables)
        //            .throttle(.seconds(1), scheduler: MainScheduler.instance)
        //            .asDriver(onErrorDriveWith: .empty())
        //            .drive(onNext: { [weak self] in
        //                self?.createClipMenu()
        //            })
        //            .disposed(by: disposeBag)
        
        self.buildClipMenuViewForStatusItem() // TODO[q]
    }
}

// MARK: - Menus
extension MenuManager {
    fileprivate func createClipMenu() {
        // print("CREATE CLIP MENU")
        if clipMenu == nil {
            clipMenu = NSMenu(title: Constants.Application.name)
        }
        historyMenu = NSMenu(title: Constants.Menu.history)
        snippetMenu = NSMenu(title: Constants.Menu.snippet)

        if let highlightItem = clipMenu?.highlightedItem {
            highlightItem.isEnabled = false
            clipMenu?.removeItem(highlightItem)
            clipMenu?.update()  // Force removing the background highlight first
        }
        // Loop though all items and remove all except the search bar
        for item in clipMenu!.items {
            if item is CPYTextFieldMenuItem {
                continue
            }
            clipMenu?.removeItem(item)
        }

        if (clipMenu?.items.isEmpty ?? false)
            || !(clipMenu?.item(at: 0) is CPYTextFieldMenuItem)
        {
            clipMenu?.addItem(
                CPYTextFieldMenuItem(
                    title: "Search all",
                    action: nil,
                    keyEquivalent: ""
                ))
        }

        //  historyMenu?.addItem(CPYTextFieldMenuItem(
        //     title: "Search history",
        //     action: nil,
        //     keyEquivalent: ""
        // ))
        //  snippetMenu?.addItem(CPYTextFieldMenuItem(
        //     title: "Search snippet",
        //     action: nil,
        //     keyEquivalent: ""
        // ))
        let maxHistorySize = AppEnvironment.current.defaults.integer(
            forKey: Constants.UserDefaults.maxHistorySize)
        let ascending = !AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        let clipResults = realm.objects(CPYClip.self)
            .sorted(
                byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending
            )
            .toArray(type: CPYClip.self, limit: maxHistorySize)
        addHistoryItems(clipMenu!, clipResults: clipResults)
        addHistoryItems(historyMenu!, clipResults: clipResults)

        addSnippetItems(clipMenu!, separateMenu: true)
        addSnippetItems(snippetMenu!, separateMenu: false)

        clipMenu?.addItem(NSMenuItem.separator())

        if AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.addClearHistoryMenuItem)
        {
            clipMenu?.addItem(
                NSMenuItem(
                    title: L10n.clearHistory,
                    action: #selector(AppDelegate.clearAllHistory)))
        }

        clipMenu?.addItem(
            NSMenuItem(
                title: L10n.editSnippets,
                action: #selector(AppDelegate.showSnippetEditorWindow)))
        clipMenu?.addItem(
            NSMenuItem(
                title: L10n.preferences,
                action: #selector(AppDelegate.showPreferenceWindow)))
        clipMenu?.addItem(NSMenuItem.separator())
        clipMenu?.addItem(
            NSMenuItem(
                title: L10n.quitClipy, action: #selector(AppDelegate.terminate))
        )

        statusItem?.menu = clipMenu
    }

    fileprivate func menuItemTitle(
        _ title: String, listNumber: NSInteger, isMarkWithNumber: Bool
    ) -> String {
        return (isMarkWithNumber) ? "\(listNumber). \(title)" : title
    }

    fileprivate func makeSubmenuItem(
        _ count: Int, start: Int, end: Int, numberOfItems: Int
    ) -> NSMenuItem {
        var count = count
        if start == 0 {
            count -= 1
        }
        var lastNumber = count + numberOfItems
        if end < lastNumber {
            lastNumber = end
        }
        let menuItemTitle = "\(count + 1) - \(lastNumber)"
        return makeSubmenuItem(menuItemTitle)
    }

    fileprivate func makeSubmenuItem(_ title: String) -> NSMenuItem {
        let subMenu = NSMenu(title: "")
        let subMenuItem = NSMenuItem(title: title, action: nil)
        subMenuItem.submenu = subMenu
        subMenuItem.image =
            (AppEnvironment.current.defaults.bool(
                forKey: Constants.UserDefaults.showIconInTheMenu))
            ? folderIcon : nil
        return subMenuItem
    }

    fileprivate func incrementListNumber(
        _ listNumber: NSInteger, max: NSInteger, start: NSInteger
    ) -> NSInteger {
        var listNumber = listNumber + 1
        if listNumber == max && max == 10 && start == 1 {
            listNumber = 0
        }
        return listNumber
    }

    fileprivate func trimTitle(_ title: String?) -> String {
        if title == nil { return "" }
        let theString =
            title!.trimmingCharacters(in: .whitespacesAndNewlines) as NSString

        let aRange = NSRange(location: 0, length: 0)
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        theString.getLineStart(
            &lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: aRange)

        var titleString =
            (lineEnd == theString.length)
            ? theString as String : theString.substring(to: contentsEnd)

        var maxMenuItemTitleLength = AppEnvironment.current.defaults.integer(
            forKey: Constants.UserDefaults.maxMenuItemTitleLength)
        if maxMenuItemTitleLength < shortenSymbol.count {
            maxMenuItemTitleLength = shortenSymbol.count
        }

        if titleString.utf16.count > maxMenuItemTitleLength {
            titleString =
                (titleString as NSString).substring(
                    to: maxMenuItemTitleLength - shortenSymbol.count)
                + shortenSymbol
        }

        return titleString as String
    }
}

// MARK: - Clips
extension MenuManager {
    fileprivate func addHistoryItems(
        _ menu: NSMenu, clipResults: [CPYClip]
    ) {
        let placeInLine = AppEnvironment.current.defaults.integer(
            forKey: Constants.UserDefaults.numberOfItemsPlaceInline)
        let placeInsideFolder = AppEnvironment.current.defaults.integer(
            forKey: Constants.UserDefaults.numberOfItemsPlaceInsideFolder)
        let maxHistory = AppEnvironment.current.defaults.integer(
            forKey: Constants.UserDefaults.maxHistorySize)

        // History title
        let labelItem = NSMenuItem(title: L10n.history, action: nil)
        labelItem.isEnabled = false
        menu.addItem(labelItem)

        // History
        let firstIndex = firstIndexOfMenuItems()
        var listNumber = firstIndex
        var subMenuCount = placeInLine
        var subMenuIndex = 1 + placeInLine

        //        let ascending = !AppEnvironment.current.defaults.bool(
        //            forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        //        let clipResults = realm.objects(CPYClip.self).sorted(
        //            byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending)

        let currentSize = Int(clipResults.count)
        var i = 0
        for clip in clipResults {
            if placeInLine < 1 || placeInLine - 1 < i {
                // Folder
                if i == subMenuCount {
                    let subMenuItem = makeSubmenuItem(
                        subMenuCount, start: firstIndex, end: currentSize,
                        numberOfItems: placeInsideFolder)
                    menu.addItem(subMenuItem)
                    listNumber = firstIndex
                }

                // Clip
                if let subMenu = menu.item(at: subMenuIndex)?.submenu {
                    let menuItem = makeClipMenuItem(
                        clip, index: i, listNumber: listNumber)
                    subMenu.addItem(menuItem)
                    listNumber = incrementListNumber(
                        listNumber, max: placeInsideFolder, start: firstIndex)
                }
            } else {
                // Clip
                let menuItem = makeClipMenuItem(
                    clip, index: i, listNumber: listNumber)
                menu.addItem(menuItem)
                listNumber = incrementListNumber(
                    listNumber, max: placeInLine, start: firstIndex)
            }

            i += 1
            if i == subMenuCount + placeInsideFolder {
                subMenuCount += placeInsideFolder
                subMenuIndex += 1
            }

            if maxHistory <= i { break }
        }
    }

    fileprivate func makeClipMenuItem(
        _ clip: CPYClip, index: Int, listNumber: Int
    ) -> NSMenuItem {
        let isMarkWithNumber = AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        let isShowToolTip = AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.showToolTipOnMenuItem)
        let isShowImage = AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.showImageInTheMenu)
        let isShowColorCode = AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.showColorPreviewInTheMenu)
        let addNumbericKeyEquivalents = AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.addNumericKeyEquivalents)

        var keyEquivalent = ""

        if addNumbericKeyEquivalents && (index <= kMaxKeyEquivalents) {
            let isStartFromZero = AppEnvironment.current.defaults.bool(
                forKey: Constants.UserDefaults.menuItemsTitleStartWithZero)

            var shortCutNumber = (isStartFromZero) ? index : index + 1
            if shortCutNumber == kMaxKeyEquivalents {
                shortCutNumber = 0
            }
            keyEquivalent = "\(shortCutNumber)"
        }

        let primaryPboardType = NSPasteboard.PasteboardType(
            rawValue: clip.primaryType)
        let clipString = clip.title
        let title = trimTitle(clipString)
        let titleWithMark = menuItemTitle(
            title, listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)

        let menuItem = NSMenuItem(
            title: titleWithMark,
            action: #selector(AppDelegate.selectClipMenuItem(_:)),
            keyEquivalent: keyEquivalent)
        menuItem.representedObject = clip.dataHash

        if isShowToolTip {
            let maxLengthOfToolTip = AppEnvironment.current.defaults.integer(
                forKey: Constants.UserDefaults.maxLengthOfToolTip)
            let toIndex =
                (clipString.count < maxLengthOfToolTip)
                ? clipString.count : maxLengthOfToolTip
            menuItem.toolTip = (clipString as NSString).substring(to: toIndex)
        }

        if primaryPboardType == .deprecatedTIFF {
            menuItem.title = menuItemTitle(
                "(Image)", listNumber: listNumber,
                isMarkWithNumber: isMarkWithNumber)
        } else if primaryPboardType == .deprecatedPDF {
            menuItem.title = menuItemTitle(
                "(PDF)", listNumber: listNumber,
                isMarkWithNumber: isMarkWithNumber)
        } else if primaryPboardType == .deprecatedFilenames && title.isEmpty {
            menuItem.title = menuItemTitle(
                "(Filenames)", listNumber: listNumber,
                isMarkWithNumber: isMarkWithNumber)
        }

        if !clip.thumbnailPath.isEmpty && !clip.isColorCode && isShowImage {
            PINCache.shared.object(forKeyAsync: clip.thumbnailPath) {
                [weak menuItem] _, _, object in
                DispatchQueue.main.async {
                    menuItem?.image = object as? NSImage
                }
            }
        }
        if !clip.thumbnailPath.isEmpty && clip.isColorCode && isShowColorCode {
            PINCache.shared.object(forKeyAsync: clip.thumbnailPath) {
                [weak menuItem] _, _, object in
                DispatchQueue.main.async {
                    menuItem?.image = object as? NSImage
                }
            }
        }

        return menuItem
    }
}

// MARK: - Snippets
extension MenuManager {
    fileprivate func addSnippetItems(_ menu: NSMenu, separateMenu: Bool) {
        let folderResults = realm.objects(CPYFolder.self).sorted(
            byKeyPath: #keyPath(CPYFolder.index), ascending: true)
        guard !folderResults.isEmpty else { return }
        if separateMenu {
            menu.addItem(NSMenuItem.separator())
        }

        // Snippet title
        let labelItem = NSMenuItem(title: L10n.snippet, action: nil)
        labelItem.isEnabled = false
        menu.addItem(labelItem)

        var subMenuIndex = menu.numberOfItems - 1
        let firstIndex = firstIndexOfMenuItems()

        folderResults
            .filter { $0.enable }
            .forEach { folder in
                let folderTitle = folder.title
                let subMenuItem = makeSubmenuItem(folderTitle)
                menu.addItem(subMenuItem)
                subMenuIndex += 1

                var i = firstIndex
                folder.snippets
                    .sorted(
                        byKeyPath: #keyPath(CPYSnippet.index), ascending: true
                    )
                    .filter { $0.enable }
                    .forEach { snippet in
                        let subMenuItem = makeSnippetMenuItem(
                            snippet, listNumber: i)
                        if let subMenu = menu.item(at: subMenuIndex)?.submenu {
                            subMenu.addItem(subMenuItem)
                            i += 1
                        }
                    }
            }
    }

    fileprivate func makeSnippetMenuItem(_ snippet: CPYSnippet, listNumber: Int)
        -> NSMenuItem
    {
        let isMarkWithNumber = AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        let isShowIcon = AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.showIconInTheMenu)

        let title = trimTitle(snippet.title)
        let titleWithMark = menuItemTitle(
            title, listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)

        let menuItem = NSMenuItem(
            title: titleWithMark,
            action: #selector(AppDelegate.selectSnippetMenuItem(_:)),
            keyEquivalent: "")
        menuItem.representedObject = snippet.identifier
        menuItem.toolTip = snippet.content
        menuItem.image = (isShowIcon) ? snippetIcon : nil

        return menuItem
    }
}

// MARK: - Status Item
extension MenuManager {
    fileprivate func changeStatusItem(_ type: StatusType) {
        removeStatusItem()
        if type == .none { return }

        let image: NSImage?
        switch type {
        case .black:
            image = Asset.statusbarMenuBlack.image
        case .white:
            image = Asset.statusbarMenuWhite.image
        case .none: return
        }
        image?.isTemplate = true

        statusItem = NSStatusBar.system.statusItem(withLength: -1)
        statusItem?.button?.image = image
        statusItem?.highlightMode = true
        statusItem?.button?.toolTip =
            "\(Constants.Application.name) \(Bundle.main.appVersion ?? "")"
        // TODO[q]: Trigger rebuild on statusItem everytime clicked
        statusItem?.button?.action = #selector(MenuManager.buildClipMenuViewForStatusItem)
    }

    fileprivate func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc fileprivate func buildClipMenuViewForStatusItem() {
        self.globalMenuView = self.buildClipMenuView()
        self.statusItem?.menu = self.globalMenuView
    }
}

// MARK: - Settings
extension MenuManager {
    fileprivate func firstIndexOfMenuItems() -> NSInteger {
        return AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.menuItemsTitleStartWithZero) ? 0 : 1
    }
}

// MARK: Build menu views on first popup
extension MenuManager {
    func buildMenuViewsOnFirstPaint(menuType: MenuType) -> NSMenu {
        switch menuType {
        case .main:
            return buildClipMenuView()
        case .history:
            return buildHistoryMenuView()
        case .snippet:
            return buildSnippetMenuView()
        default:
            return NSMenu()
        }
    }

    func refreshMenuViewsOnSearch(searchText: String) {
        switch self.lastDisplayedMenuType {
        case .main:
            self.refreshClipMenuOnSearch(searchText: searchText)
        case .history:
                self.refreshHistoryMenuOnSearch(searchText: searchText)
        case .snippet:
                self.refreshSnippetMenuOnSearch(searchText: searchText)
        default:
            return
        }
    }
}

// MARK: Main menu (Clip)
extension MenuManager {
    fileprivate func buildClipMenuView() -> NSMenu {
        let menu = NSMenu(title: Constants.Application.name)

        // Search box
        menu.addItem(
            CPYTextFieldMenuItem(
                title: "Search",
                action: nil,
                keyEquivalent: ""
            )
        )

        // Histories
        let maxHistorySize = AppEnvironment.current.defaults.integer(
            forKey: Constants.UserDefaults.maxHistorySize)
        let ascending = !AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        let clipResults = realm.objects(CPYClip.self)
            .sorted(
                byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending
            )
            .toArray(type: CPYClip.self, limit: maxHistorySize)

        addHistoryItems(menu, clipResults: clipResults)
        addSnippetItems(menu, separateMenu: true)
        addSettingsMenuItems(menu, separateMenu: true)

        return menu
    }

    fileprivate func refreshClipMenuOnSearch(searchText: String) {
        guard let menu = self.globalMenuView else { return }

        // Loop though all items and remove all except the search bar
        if let highlightItem = menu.highlightedItem {
            highlightItem.isEnabled = false
            self.globalMenuView?.removeItem(highlightItem)
            self.globalMenuView?.update()  // Force removing the background highlight first
        }
        for item in menu.items {
            if item is CPYTextFieldMenuItem {
                continue
            }
            menu.removeItem(item)
        }

        let maxHistorySize = AppEnvironment.current.defaults.integer(
            forKey: Constants.UserDefaults.maxHistorySize)
        let ascending = !AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.reorderClipsAfterPasting)

        var clipResults: [CPYClip] = []
        if searchText.isEmpty {
            clipResults = realm.objects(CPYClip.self)
                .sorted(
                    byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending
                )
                .toArray(type: CPYClip.self, limit: maxHistorySize)
        } else {
            clipResults = realm.objects(CPYClip.self)
                .where { $0.title.contains(searchText, options: .caseInsensitive) }
                .sorted(
                    byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending
                )
                .toArray(type: CPYClip.self, limit: 10)  // TODO[q]
        }

        addHistoryItems(menu, clipResults: clipResults)
        addSnippetItems(menu, separateMenu: true)
        addSettingsMenuItems(menu, separateMenu: true)

        self.globalMenuView = menu
        self.globalMenuView?.update()
    }

    fileprivate func addSettingsMenuItems(_ parentMenu: NSMenu, separateMenu: Bool) {
        if separateMenu {
            parentMenu.addItem(NSMenuItem.separator())
        }

        if AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.addClearHistoryMenuItem)
        {
            parentMenu.addItem(
                NSMenuItem(
                    title: L10n.clearHistory,
                    action: #selector(AppDelegate.clearAllHistory)))
        }

        parentMenu.addItem(
            NSMenuItem(
                title: L10n.editSnippets,
                action: #selector(AppDelegate.showSnippetEditorWindow)))
        parentMenu.addItem(
            NSMenuItem(
                title: L10n.preferences,
                action: #selector(AppDelegate.showPreferenceWindow)))
        parentMenu.addItem(NSMenuItem.separator())
        parentMenu.addItem(
            NSMenuItem(
                title: L10n.quitClipy, action: #selector(AppDelegate.terminate))
        )
    }
}

// MARK: History menu
extension MenuManager {
    fileprivate func buildHistoryMenuView() -> NSMenu {
        let menu = NSMenu(title: Constants.Application.name)

        // Search box
        menu.addItem(
            CPYTextFieldMenuItem(
                title: "Search",
                action: nil,
                keyEquivalent: ""
            )
        )

        // Histories
        let maxHistorySize = AppEnvironment.current.defaults.integer(
            forKey: Constants.UserDefaults.maxHistorySize)
        let ascending = !AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        let clipResults = realm.objects(CPYClip.self)
            .sorted(
                byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending
            )
            .toArray(type: CPYClip.self, limit: maxHistorySize)
        addHistoryItems(menu, clipResults: clipResults)

        return menu
    }

    fileprivate func refreshHistoryMenuOnSearch(searchText: String) {
        guard let menu = self.globalMenuView else { return }

        // Loop though all items and remove all except the search bar
        if let highlightItem = menu.highlightedItem {
            highlightItem.isEnabled = false
            self.globalMenuView?.removeItem(highlightItem)
            self.globalMenuView?.update()  // Force removing the background highlight first
        }
        for item in menu.items {
            if item is CPYTextFieldMenuItem {
                continue
            }
            menu.removeItem(item)
        }

        let maxHistorySize = AppEnvironment.current.defaults.integer(
            forKey: Constants.UserDefaults.maxHistorySize)
        let ascending = !AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.reorderClipsAfterPasting)

        var clipResults: [CPYClip] = []
        if searchText.isEmpty {
            clipResults = realm.objects(CPYClip.self)
                .sorted(
                    byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending
                )
                .toArray(type: CPYClip.self, limit: maxHistorySize)
        } else {
            clipResults = realm.objects(CPYClip.self)
                .where { $0.title.contains(searchText, options: .caseInsensitive) }
                .sorted(
                    byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending
                )
                .toArray(type: CPYClip.self, limit: 10)  // TODO[q]
        }

        addHistoryItems(menu, clipResults: clipResults)

        self.globalMenuView = menu
        self.globalMenuView?.update()
    }
}

// MARK: Snippet menu
extension MenuManager {
    fileprivate func buildSnippetMenuView() -> NSMenu {
        let menu = NSMenu(title: Constants.Application.name)

        // Search box
        menu.addItem(
            CPYTextFieldMenuItem(
                title: "Search",
                action: nil,
                keyEquivalent: ""
            )
        )

        // Snippets
        addSnippetItems(menu, separateMenu: true)

        return menu
    }
    
    fileprivate func refreshSnippetMenuOnSearch(searchText: String) {
        // TODO[q]: Search snippets
    }
}
