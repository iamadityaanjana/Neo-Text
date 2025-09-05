//
//  EditorView.swift
//  Neo
//
//  Created by Aditya Anjana on 05/09/25.
//

import SwiftUI
import Foundation
import AppKit

struct EditorView: View {
    @ObservedObject var documentManager: DocumentManager
    @Binding var selectedDocument: Document?
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var content: String = ""
    @State private var richContent: Data? = nil
    @State private var title: String = ""
    @State private var focusMode: Bool = false
    @State private var currentLineIndex: Int = 0
    @State private var contentRefreshTrigger = false
    @State private var didLoad = false
    @State private var cachePath: String? = nil
    
    private var editorBackground: Color {
        isDarkMode ? Color.black : Color(red: 0.96, green: 0.96, blue: 0.86)
    }
    
    var body: some View {

        ZStack { editorBackground.ignoresSafeArea(); mainStack }

            .onAppear(perform: loadSelectedDocument)

            .onChange(of: selectedDocument?.id) { _ in reloadForSelectionChange() }

            .onChange(of: content) { autoSave() }

            .onChange(of: richContent) { autoSave() }

            .onChange(of: cachePath) { autoSave() }

            .onChange(of: title) { autoSave() }

            .animation(.default, value: focusMode)

            .preferredColorScheme(isDarkMode ? .dark : .light)

    }

    // MARK: - Extracted Views
    private var mainStack: some View {
        VStack(spacing: 0) {
            if focusMode {
                focusTopBar
            } else {
                normalTopBar
            }
            if !focusMode { titleField }
            editorArea
            Spacer()
        }
    }

    private var normalTopBar: some View {
        HStack(alignment: .center, spacing: 12) {
            MinimalCircleButton(symbol: "arrow.left", accessibilityLabel: "Back", isDark: isDarkMode) {
                saveDocument(); selectedDocument = nil
            }
            Spacer()
            MinimalCircleButton(symbol: isDarkMode ? "sun.max.fill" : "moon.fill", accessibilityLabel: "Toggle Appearance", isDark: isDarkMode) {
                isDarkMode.toggle()
            }
            MinimalCircleButton(symbol: focusMode ? "xmark" : "scope", accessibilityLabel: "Focus Mode", isDark: isDarkMode) {
                focusMode.toggle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private var focusTopBar: some View {
        HStack {
            Spacer()
            MinimalCircleButton(symbol: "xmark", accessibilityLabel: "Exit Focus", isDark: isDarkMode) {
                focusMode = false
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, 30)
    }

    private var titleField: some View {
        TextField("Title", text: $title)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 32, weight: .bold, design: .default))
            .foregroundColor(isDarkMode ? .white : .black)
            .padding(.horizontal, 60)
            .padding(.bottom, 20)
    }

    @ViewBuilder private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            if focusMode {
                VStack(spacing: 0) {
                    HStack { Spacer(); centeredTitle; Spacer() }
                        .padding(.top, 60)
                        .padding(.bottom, 40)
                    FocusTextEditorRepresentable(
                        text: $content,
                        richContent: $richContent,
                        cachePath: $cachePath,
                        docId: selectedDocument?.id,
                        currentLine: $currentLineIndex,
                        isDark: isDarkMode,
                        centerLine: false,
                        fontSize: 22
                    )
                    .id("\(selectedDocument?.id.uuidString ?? "")-\(cachePath ?? "nil")-focus")
                }
                .padding(.horizontal, 60)
                .transition(.opacity)
            } else {
                CustomTextEditor(
                    text: $content,
                    richContent: $richContent,
                    cachePath: $cachePath,
                    docId: selectedDocument?.id,
                    font: .monospacedSystemFont(ofSize: 18, weight: .regular),
                    textColor: isDarkMode ? .white : .black,
                    backgroundColor: .clear
                )
                .id("\(selectedDocument?.id.uuidString ?? "")-\(cachePath ?? "nil")-normal")
                .padding(.horizontal, 60)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .transition(.opacity)
            }

            if content.isEmpty && !focusMode {
                Text("Start from here...")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor((isDarkMode ? Color.white : Color.black).opacity(0.32))
                    .padding(.horizontal, 60)
                    .padding(.top, 10)
            }
        }
    }

    private var centeredTitle: some View {
        TextField("Title", text: $title)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 32, weight: .bold, design: .default))
            .foregroundColor(isDarkMode ? .white : .black)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 600)
    }
    
    private func autoSave() {
    guard didLoad else { return }
        guard var doc = selectedDocument else { return }
        doc.title = title
        doc.content = content
    doc.richContent = richContent
    doc.cachePath = cachePath
        doc.lastEdited = Date()
        documentManager.updateDocument(doc)
        selectedDocument = doc
    }
    
    private func saveDocument() { autoSave() }

    private func loadSelectedDocument() {
        if let doc = selectedDocument {
            title = doc.title
            content = doc.content
            richContent = doc.richContent
            cachePath = doc.cachePath
            didLoad = true
        }
    }

    private func reloadForSelectionChange() {
        didLoad = false
        if let doc = selectedDocument {
            title = doc.title
            content = doc.content
            richContent = doc.richContent
            cachePath = doc.cachePath
        } else {
            title = ""
            content = ""
            richContent = nil
            cachePath = nil
        }
        didLoad = true
    }
}
