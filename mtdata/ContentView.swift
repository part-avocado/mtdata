//
//  ContentView.swift
//  mtdata
//
//  Created by James on 2025/10/20.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: mtdataDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(mtdataDocument()))
}
