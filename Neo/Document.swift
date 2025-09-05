//
//  Document.swift
//  Neo
//
//  Created by Aditya Anjana on 05/09/25.
//

import Foundation

struct Document: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var content: String
    var richContent: Data? // Store RTF data to preserve images and formatting
    var creationDate: Date
    var lastEdited: Date
}
