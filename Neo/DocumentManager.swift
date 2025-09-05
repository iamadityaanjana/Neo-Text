//
//  DocumentManager.swift
//  Neo
//
//  Created by Aditya Anjana on 05/09/25.
//

import Foundation

class DocumentManager: ObservableObject {
    @Published var documents: [Document] = []
    private let fileName = "documents.json"
    
    init() {
        loadDocuments()
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    private func getFileURL() -> URL {
        return getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    func loadDocuments() {
        let fileURL = getFileURL()
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            // Attempt to decode current schema first
            do {
                documents = try decoder.decode([Document].self, from: data)
            } catch {
                // Fallback: migrate from legacy schema without richContent
                struct LegacyDocument: Codable {
                    var id: UUID?
                    var title: String
                    var content: String
                    var creationDate: Date?
                    var lastEdited: Date?
                }
                let legacy = try decoder.decode([LegacyDocument].self, from: data)
                let migrated: [Document] = legacy.map { ld in
                    Document(
                        id: ld.id ?? UUID(),
                        title: ld.title,
                        content: ld.content,
                        richContent: nil,
                        creationDate: ld.creationDate ?? Date(),
                        lastEdited: ld.lastEdited ?? Date()
                    )
                }
                documents = migrated
                saveDocuments() // write back in new schema to avoid repeated migration
            }
        } catch {
            print("Error loading documents: \(error)")
            documents = []
        }
    }
    
    func saveDocuments() {
        let fileURL = getFileURL()
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: fileURL)
        } catch {
            print("Error saving documents: \(error)")
        }
    }
    
    func addDocument(title: String, content: String = "") {
        let newDoc = Document(title: title, content: content, richContent: Data(), creationDate: Date(), lastEdited: Date())
        documents.append(newDoc)
        saveDocuments()
    }
    
    func updateDocument(_ document: Document) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = document
            saveDocuments()
        }
    }
    
    func deleteDocument(_ document: Document) {
        documents.removeAll { $0.id == document.id }
        saveDocuments()
    }
    
    func renameDocument(_ document: Document, newTitle: String) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index].title = newTitle
            documents[index].lastEdited = Date()
            saveDocuments()
        }
    }
}
