//
//  ViewControllersManager.swift
//  Aria2D
//
//  Created by xjbeta on 16/2/28.
//  Copyright © 2016年 xjbeta. All rights reserved.
//

import Foundation
import Cocoa

class ViewControllersManager: NSObject {

    static let shared = ViewControllersManager()
    
    private override init() {
        super.init()
    }
	
	
	// MainWindow HUD
	func showHUD(_ message: hudMessage) {
		NotificationCenter.default.post(name: .showHUD, object: nil, userInfo: [ "message": message])
	}
	
	
	// LeftSourceList Indicator
	private var waitingCount = 0
	
	var updateIndicator: (() -> Void)?
	
	var waiting: Bool {
		get {
			return waitingCount > 0
		}
		set {
			if newValue {
				waitingCount += 1
			} else if waitingCount > 0 {
				waitingCount -= 1
			}
			updateIndicator?()
		}
	}
	
	
    // LeftSourceList
    var selectedRowDidSet: (() -> Void)?
    
    var selectedRow: leftSourceListRow = .none {
        willSet {
            if newValue == .baidu {
                Baidu.shared.getFileList(forPath: Baidu.shared.selectedPath)
            }
        }
        didSet {
            selectedRowDidSet?()
        }
    }

	// DownloadsTableView selectedIndexs
    var selectedIndexs = IndexSet()
	func showOptions() {
		NotificationCenter.default.post(name: .showOptionsWindow, object: self)
	}
	
	func showSelectedInFinder() {
		let urls = selectedUrls()
		if urls.count > 0 {
			NSWorkspace.shared().activateFileViewerSelecting(urls)
		}
	}
	
	func openSelected() {
		guard Preferences.shared.aria2Servers.isLocal else { return }
		DataManager.shared.data(TaskObject.self).map {
			URL(fileURLWithPath: $0.path)
			}.enumerated().filter {
				selectedIndexs.contains($0.offset)
			}.map {
				$0.element
			}.filter {
				FileManager.default.fileExists(atPath: $0.path)
			}.forEach {
			NSWorkspace.shared().open($0)
		}
	}
	
	func selectedUrls() -> [URL] {
		var urls = DataManager.shared.data(TaskObject.self).map {
			URL(fileURLWithPath: $0.path)
			}.enumerated().filter {
				selectedIndexs.contains($0.offset)
			}.map {
				$0.element
		}
		urls = urls.map {
			URL(fileURLWithPath: $0.path + ".aria2")
			} + urls
		return urls.filter {
			FileManager.default.fileExists(atPath: $0.path)
		}
	}
	
	
	func showStatus() {
		NotificationCenter.default.post(name: .showStatusWindow, object: self)
	}
	
	// LogViewController
	var webSocketLog: [WebSocketLog] = []
	
	// Front Window
	enum frontWindow {
		case main, preference, changeOption, about, other
	}
	var mainWindowFront: Bool {
		get {
			return NSApp.keyWindow?.windowController is MainWindowController
		}
	}
	
	
	// Aria2 Task

	
	var tasksShouldPause: Bool {
		get {
			if selectedRow == .downloading {
				let dataList = selectedIndexs.map {
					DataManager.shared.data(TaskObject.self)[$0]
				}
				let canPauseList = dataList.filter {
					$0.status == "active" || $0.status == "waiting"
				}
				let pausedList = dataList.filter {
					$0.status == "paused"
				}
				if canPauseList.count >= pausedList.count {
					return true
				}
			}
			return false
		}
	}
	
	func pauseOrUnpause() {
		if selectedRow == .downloading {
			let dataList = selectedIndexs.map {
				DataManager.shared.data(TaskObject.self)[$0]
			}
			let canPauseList = dataList.filter {
				$0.status == "active" || $0.status == "waiting"
			}
			let pausedList = dataList.filter {
				$0.status == "paused"
			}
			if canPauseList.count >= pausedList.count {
				Aria2.shared.pause(canPauseList.map { $0.gid })
			} else if canPauseList.count < pausedList.count {
				Aria2.shared.unpause(pausedList.map { $0.gid })
			}
		}
	}
	
	func deleteTask() {
		var gidForRemoveDownloadResult = [GID]()
		var gidForRemove = [GID]()
		
		ViewControllersManager.shared.selectedIndexs.forEach {
			let data = DataManager.shared.data(TaskObject.self)[$0]
			let status = data.status
			let gid = data.gid
			if status == "complete" || status == "error" || status == "removed" {
				gidForRemoveDownloadResult.append(gid)
			} else {
				gidForRemove.append(gid)
			}
		}
		
		Aria2.shared.removeDownloadResult(gidForRemoveDownloadResult)
		Aria2.shared.remove(gidForRemove)
	}
	
	func refresh() {
		switch selectedRow {
		case .downloading, .completed, .removed:
			Aria2.shared.initData()
		case .baidu:
			Baidu.shared.getFileList(forPath: Baidu.shared.selectedPath)
		default:
			break
		}
	}
}