//
//  ClipService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/11/17.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import Foundation
import PINCache
import RealmSwift
import RxCocoa
import RxSwift

final class ClipService {

    // MARK: - Properties
    fileprivate var cachedChangeCount = BehaviorRelay<Int>(value: 0)
    fileprivate var storeTypes = [String: NSNumber]()
    fileprivate let scheduler = SerialDispatchQueueScheduler(
        qos: .userInteractive)
    fileprivate let lock = NSRecursiveLock(
        name: "com.clipy-app.Clipy.ClipUpdatable")
    fileprivate var disposeBag = DisposeBag()

    // MARK: - Clips
    func startMonitoring() {
        disposeBag = DisposeBag()

        // Pasteboard observe timer
        Observable<Int>.interval(.milliseconds(100), scheduler: scheduler)
            .map { _ in NSPasteboard.general.changeCount }
            .withLatestFrom(cachedChangeCount.asObservable()) { ($0, $1) }
            .filter { $0 != $1 }
            .subscribe(onNext: { [weak self] changeCount, _ in
                self?.cachedChangeCount.accept(changeCount)
                self?.captureClipboardChange()
            })
            .disposed(by: disposeBag)

        // Store types
        AppEnvironment.current.defaults.rx
            .observe([String: NSNumber].self, Constants.UserDefaults.storeTypes)
            .compactMap { $0 }
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] in
                self?.storeTypes = $0
            })
            .disposed(by: disposeBag)
    }

    func clearAll() {
        let realm = try! Realm()
        let clips = realm.objects(CPYClip.self)

        // Delete saved images
        clips
            .filter { !$0.thumbnailPath.isEmpty }
            .map { $0.thumbnailPath }
            .forEach { PINCache.shared.removeObject(forKey: $0) }
        // Delete Realm
        realm.transaction { realm.delete(clips) }
        // Delete writed datas
        AppEnvironment.current.dataCleanService.cleanDatas()
    }

    func delete(with clip: CPYClip) {
        let realm = try! Realm()
        // Delete saved images
        let path = clip.thumbnailPath
        if !path.isEmpty {
            PINCache.shared.removeObject(forKey: path)
        }
        // Delete Realm
        realm.transaction { realm.delete(clip) }
    }

    func incrementChangeCount() {
        cachedChangeCount.accept(cachedChangeCount.value + 1)
    }

}

// MARK: - Create Clip
extension ClipService {
    fileprivate func captureClipboardChange() {
        lock.lock()
        defer { lock.unlock() }

        // Store types
        if !storeTypes.values.contains(NSNumber(value: true)) { return }
        // Pasteboard types
        let pasteboard = NSPasteboard.general
        let captureableTypes = self.getCaptureableTypesFromPasteboard(with: pasteboard)
        if captureableTypes.isEmpty { return }

        // Excluded application
        guard
            !AppEnvironment.current.excludeAppService
                .frontProcessIsExcludedApplication()
        else { return }
        // Special applications
        guard
            !AppEnvironment.current.excludeAppService
                .copiedProcessIsExcludedApplications(pasteboard: pasteboard)
        else { return }

        // Create data
        let data = CPYClipData(pasteboard: pasteboard, captureableTypes: captureableTypes)

        save(with: data)
    }

    func captureImage(with image: NSImage) {
        lock.lock()
        defer { lock.unlock() }

        // Create only image data
        let data = CPYClipData(image: image)
        save(with: data)
    }

    fileprivate func save(with data: CPYClipData) {
        let realm = try! Realm()

        if let existingClipInRealm = realm.object(
            ofType: CPYClip.self, forPrimaryKey: "\(data.hash)")
        {
            // Don't save invalidated clip
            if existingClipInRealm.isInvalidated { return }

            // Copy already copied history
            let isCopySameHistory = AppEnvironment.current.defaults.bool(
                forKey: Constants.UserDefaults.copySameHistory)
            if !isCopySameHistory { return }
        }

        // Don't save empty string history
        if data.isOnlyStringType && data.stringValue.isEmpty { return }

        // Overwrite same history
        let isOverwriteHistory = AppEnvironment.current.defaults.bool(
            forKey: Constants.UserDefaults.overwriteSameHistory)
        let savedHash =
        (isOverwriteHistory) ? data.hash : Int.random(in: 0..<1_000_000)

        // Saved time and path
        let unixTime = Int(Date().timeIntervalSince1970)
        let savedPath = CPYUtilities.applicationSupportFolder() + "/\(NSUUID().uuidString).data"
        // Create Realm object
        let clip = CPYClip()
        clip.dataPath = savedPath
        clip.title = data.stringValue[0...10_000]  // TODO[q]: This may fail search on long text, but is it acceptable?
        clip.dataHash = "\(savedHash)"
        clip.updateTime = unixTime
        clip.primaryType = data.primaryType?.rawValue ?? ""

        DispatchQueue.main.async {
            // Save thumbnail image
            if let thumbnailImage = data.thumbnailImage {
                PINCache.shared.setObjectAsync(
                    thumbnailImage, forKey: "\(unixTime)", completion: nil)
                clip.thumbnailPath = "\(unixTime)"
            }
            if let colorCodeImage = data.colorCodeImage {
                PINCache.shared.setObjectAsync(
                    colorCodeImage, forKey: "\(unixTime)", completion: nil)
                clip.thumbnailPath = "\(unixTime)"
                clip.isColorCode = true
            }

            // Save Realm and .data file
            let dispatchRealm = try! Realm()
            do {
                let data = try NSKeyedArchiver.archivedData(
                    withRootObject: data, requiringSecureCoding: false)
                try data.write(to: URL(string: savedPath)!)
            } catch {
                CPYUtilities.sendCustomLog(with: "failed to save CPYClipData to storage: \(error)")
                return
            }
            dispatchRealm.transaction {
                dispatchRealm.add(clip, update: .all)
            }
        }
    }

    private func getCaptureableTypesFromPasteboard(with pasteboard: NSPasteboard) -> [NSPasteboard
        .PasteboardType]
    {
        let types = pasteboard.types?.filter { canSave(with: $0) } ?? []
        return NSOrderedSet(array: types).array
            as? [NSPasteboard.PasteboardType] ?? []
    }

    private func canSave(with type: NSPasteboard.PasteboardType) -> Bool {
        let dictionary = CPYClipData.availableTypesDictionary
        guard let value = dictionary[type] else { return false }
        guard let number = storeTypes[value] else { return false }
        return number.boolValue
    }
}
