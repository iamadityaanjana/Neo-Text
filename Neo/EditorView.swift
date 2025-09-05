//
//  EditorView.swift
//  Neo
//
//  Created by Aditya Anjana on 05/09/25.
//

import SwiftUI

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
    
    private var editorBackground: Color {
        isDarkMode ? Color.black : Color(red: 0.96, green: 0.96, blue: 0.86)
    }
    
    var body: some View {
        ZStack {
            editorBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if !focusMode {
                    HStack(alignment: .center, spacing: 12) {
                        MinimalCircleButton(symbol: "arrow.left", accessibilityLabel: "Back", isDark: isDarkMode) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                saveDocument()
                                selectedDocument = nil
                            }
                        }
                        Spacer()
                        MinimalCircleButton(symbol: isDarkMode ? "sun.max.fill" : "moon.fill", accessibilityLabel: "Toggle Appearance", isDark: isDarkMode) {
                            withAnimation(.easeInOut(duration: 0.25)) { isDarkMode.toggle() }
                        }
                        MinimalCircleButton(symbol: focusMode ? "xmark" : "scope", accessibilityLabel: "Focus Mode", isDark: isDarkMode) {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { focusMode.toggle() }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                } else {
                    // Compact top bar: just exit focus button
                    HStack {
                        Spacer()
                        MinimalCircleButton(symbol: "xmark", accessibilityLabel: "Exit Focus", isDark: isDarkMode) {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { focusMode = false }
                        }
                        .padding(.top, 24)
                    }
                    .padding(.horizontal, 30)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if !focusMode {
                    TextField("Title", text: $title)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .padding(.horizontal, 60) // Match 5vw spacing
                        .padding(.bottom, 20)
                        .transition(.opacity.combined(with: .scale))
                }
                
                ZStack(alignment: .topLeading) {
                    if focusMode {
                        // In focus mode, title should be centered at top
                        VStack(spacing: 0) {
                            // Centered title at top
                            HStack {
                                Spacer()
                                TextField("Title", text: $title)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 32, weight: .bold, design: .default))
                                    .foregroundColor(isDarkMode ? .white : .black)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 600)
                                Spacer()
                            }
                            .padding(.top, 60)
                            .padding(.bottom, 40)
                            
                            FocusTextEditorRepresentable(text: $content, richContent: $richContent, currentLine: $currentLineIndex, isDark: isDarkMode, centerLine: false, fontSize: 22)
                        }
                        .padding(.horizontal, 60) // 5vw equivalent for most screens
                        .transition(.opacity.combined(with: .scale))
                    } else {
                        CustomTextEditor(
                            text: $content,
                            richContent: $richContent,
                            font: .monospacedSystemFont(ofSize: 18, weight: .regular),
                            textColor: isDarkMode ? .white : .black,
                            backgroundColor: .clear
                        )
                        .padding(.horizontal, 60) // 5vw equivalent for most screens
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                        .transition(.opacity)
                    }
                    if content.isEmpty && !focusMode {
                        Text("Start from here...")
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor((isDarkMode ? Color.white : Color.black).opacity(0.32))
                            .padding(.horizontal, 60) // match editor horizontal padding
                            .padding(.top, 10) // closer to actual first baseline
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: focusMode)
                
                Spacer()
            }
        }
        .onAppear {
            if let doc = selectedDocument {
                title = doc.title
                content = doc.content
                richContent = doc.richContent
        didLoad = true
            }
        }
    .onChange(of: content) { autoSave() }
    .onChange(of: richContent) { autoSave() }
    .onChange(of: title) { autoSave() }
    // No explicit programmatic loading here; NSTextView handles initial rich load
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    private func autoSave() {
    guard didLoad else { return }
        guard var doc = selectedDocument else { return }
        doc.title = title
        doc.content = content
        doc.richContent = richContent
        doc.lastEdited = Date()
        documentManager.updateDocument(doc)
        selectedDocument = doc
    }
    
    private func saveDocument() {
        autoSave()
    }
}
