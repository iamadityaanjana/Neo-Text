//
//  ContentView.swift
//  Neo
//
//  Created by Aditya Anjana on 05/09/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var documentManager = DocumentManager()
    @State var selectedDocument: Document?
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    
    var body: some View {
        if isFirstLaunch {
            WelcomeView()
                .transition(.opacity)
        } else {
            if let document = selectedDocument {
                EditorView(documentManager: documentManager, selectedDocument: $selectedDocument)
                    .transition(.move(edge: .trailing))
            } else {
                DashboardView(documentManager: documentManager, selectedDocument: $selectedDocument)
                    .transition(.move(edge: .leading))
            }
        }
    }
}

#Preview {
    ContentView()
}
