//
//  DashboardView.swift
//  Neo
//
//  Created by Aditya Anjana on 05/09/25.
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var documentManager: DocumentManager
    @Binding var selectedDocument: Document?
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var searchText = ""
    @State private var showingRenameAlert = false
    @State private var documentToRename: Document?
    @State private var newTitle = ""
    @State private var showCreateAnimation = false
    @Namespace private var namespace
    
    private var background: Color { isDarkMode ? .black : Color(red: 0.96, green: 0.96, blue: 0.86) }
    
    private var filteredDocuments: [Document] {
        let docs = documentManager.documents.sorted { $0.lastEdited > $1.lastEdited }
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return docs }
        return docs.filter { doc in
            let q = searchText.lowercased()
            return doc.title.lowercased().contains(q) || doc.content.lowercased().contains(q)
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                Divider().opacity(0) // maintain spacing feel without visible line
                contentArea
            }
            
            // Floating New Button
            MinimalCircleButton(symbol: "plus", accessibilityLabel: "New Document", isDark: isDarkMode) {
                createDocument()
            }
            .padding(.trailing, 28)
            .padding(.bottom, 28)
            .overlay(
                Circle()
                    .stroke(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.15), lineWidth: 0.5)
                    .scaleEffect(showCreateAnimation ? 1.6 : 1)
                    .opacity(showCreateAnimation ? 0 : 0)
            )
        }
        .alert("Rename Document", isPresented: $showingRenameAlert, presenting: documentToRename) { _ in
            TextField("New Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { commitRename() }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    // MARK: Top Bar
    private var topBar: some View {
        HStack(spacing: 16) {
            Text("Neo")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isDarkMode ? .white : .black)
                .padding(.leading, 8)
            
            searchField
            
            MinimalCircleButton(symbol: isDarkMode ? "sun.max.fill" : "moon.fill", accessibilityLabel: "Toggle Appearance", isDark: isDarkMode) {
                withAnimation(.easeInOut(duration: 0.25)) { isDarkMode.toggle() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 12)
    }
    
    private var searchField: some View {
        ZStack(alignment: .leading) {
            if searchText.isEmpty { Text("Search...")
                .foregroundColor((isDarkMode ? Color.white : Color.black).opacity(0.35))
                .padding(.leading, 14)
            }
            TextField("", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(isDarkMode ? .white : .black)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke((isDarkMode ? Color.white : Color.black).opacity(0.12), lineWidth: 0.5)
                        )
                )
                .animation(.easeInOut(duration: 0.25), value: isDarkMode)
        }
    }
    
    // MARK: Content Area
    private var contentArea: some View {
        Group {
            if filteredDocuments.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 40)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 24, alignment: .top)], spacing: 24) {
                        ForEach(filteredDocuments) { document in
                            DocumentCard(document: document, isDark: isDarkMode)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        selectedDocument = document
                                    }
                                }
                                .contextMenu {
                                    Button("Rename") { beginRename(document) }
                                    Button("Delete", role: .destructive) { documentManager.deleteDocument(document) }
                                }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 120)
                    .padding(.top, 8)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: filteredDocuments.map { $0.id })
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("No documents yet")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(isDarkMode ? .white : .black)
            Text("Create your first note to get started. Your work auto‑saves.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor((isDarkMode ? Color.white : Color.black).opacity(0.6))
            Button(action: { createDocument() }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("New Document")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(
                    Capsule()
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                        .overlay(
                            Capsule()
                                .stroke((isDarkMode ? Color.white : Color.black).opacity(0.15), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: Actions
    private func createDocument() {
        documentManager.addDocument(title: "Untitled")
        if let newDoc = documentManager.documents.last {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedDocument = newDoc
                showCreateAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showCreateAnimation = false }
        }
    }
    private func beginRename(_ doc: Document) {
        documentToRename = doc
        newTitle = doc.title
        showingRenameAlert = true
    }
    private func commitRename() {
        if let doc = documentToRename { documentManager.renameDocument(doc, newTitle: newTitle) }
    }
}

// MARK: - Document Card
private struct DocumentCard: View {
    let document: Document
    let isDark: Bool
    @State private var hovering = false
    
    private var wordCount: Int { document.content.split { !$0.isLetter }.count }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(document.title.isEmpty ? "Untitled" : document.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isDark ? .white : .black)
                .lineLimit(2)
            Text(snippet())
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor((isDark ? Color.white : Color.black).opacity(0.55))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 4)
            HStack {
                Text("\(wordCount) words")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor((isDark ? Color.white : Color.black).opacity(0.45))
                Spacer()
                Text(relativeDate(document.lastEdited))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor((isDark ? Color.white : Color.black).opacity(0.35))
            }
        }
        .padding(16)
        .frame(minHeight: 160, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke((isDark ? Color.white : Color.black).opacity(0.10), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(isDark ? 0.5 : 0.15), radius: hovering ? 10 : 4, y: hovering ? 4 : 2)
        )
        .scaleEffect(hovering ? 1.015 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: hovering)
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Document \(document.title.isEmpty ? "Untitled" : document.title), \(wordCount) words"))
    }
    
    private func snippet() -> String {
        let text = document.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "(empty)" }
        let maxChars = 140
        return text.count > maxChars ? String(text.prefix(maxChars)) + "…" : text
    }
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// NOTE: MinimalCircleButton reused from EditorView file.
