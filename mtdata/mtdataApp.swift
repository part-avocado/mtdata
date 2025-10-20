//
//  mtdataApp.swift
//  mtdata
//
//  Created by James on 2025/10/20.
//

import SwiftUI

@main
struct mtdataApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: mtdataDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
