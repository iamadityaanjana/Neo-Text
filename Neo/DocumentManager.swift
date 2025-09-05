//
//  DocumentManager.swift
//  Neo
//
//  Created by Aditya Anjana on 05/09/25.
//

import Foundation
import Combine

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
            if let docs = try? decoder.decode([Document].self, from: data) {
                documents = docs
            } else {
                struct LegacyDocument: Codable { var id: UUID?; var title: String; var content: String; var creationDate: Date?; var lastEdited: Date? }
                if let legacy = try? decoder.decode([LegacyDocument].self, from: data) {
                    documents = legacy.map { ld in
                        let newId = ld.id ?? UUID()
                        let created = ld.creationDate ?? Date()
                        let edited = ld.lastEdited ?? created
                        return Document(id: newId, title: ld.title, content: ld.content, richContent: Optional<Data>.none, cachePath: Optional<String>.none, creationDate: created, lastEdited: edited)
                    }
                    saveDocuments()
                } else {
                    documents = []
                }
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
    let newDoc = Document(title: title, content: content, richContent: Optional<Data>.none, cachePath: Optional<String>.none, creationDate: Date(), lastEdited: Date())
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
