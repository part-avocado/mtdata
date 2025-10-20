//
//  mtdataApp.swift
//  mtdata
//
//  Created by James on 2025/10/20.
//

import SwiftUI

@main
struct mtdataApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app activates and comes to the front
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Make sure the main window is visible - try multiple times with delay
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
        
        // Backup: try again after a short delay to ensure window is created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
