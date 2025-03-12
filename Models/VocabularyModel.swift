//
//  VocabularyModel.swift
//  Language App
//
//  Created by Nathan Webster on 3/6/25.
//

import Foundation
import FirebaseFirestore

struct VocabularyModel: Identifiable {
    let id = UUID() // ✅ SwiftUI needs an ID for List views
    let word: String
    let translation: String
    let exampleSentence: String
    let difficultyLevel: String
}
