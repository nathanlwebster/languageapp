//
//  VocabularyView.swift
//  Language App
//
//  Created by Nathan Webster on 3/6/25.
//

import SwiftUI
import FirebaseFirestore

struct VocabularyView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var vocabulary: [VocabularyModel] = []
    @State private var newWord = ""
    @State private var translation = ""
    @State private var exampleSentence = ""
    @State private var difficultyLevel = "easy"
    @State private var errorMessage = ""

    let difficultyOptions = ["easy", "medium", "hard"]

    var body: some View {
        VStack {
            Text("Vocabulary List")
                .font(.largeTitle)
                .bold()
                .padding()

            // ✅ Add new word UI
            TextField("Word", text: $newWord)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Translation", text: $translation)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Example Sentence", text: $exampleSentence)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Picker("Difficulty", selection: $difficultyLevel) {
                ForEach(difficultyOptions, id: \.self) { level in
                    Text(level.capitalized).tag(level)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Button(action: addNewWord) {
                Text("Add Word")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            // ✅ Display words from Firestore
            List(vocabulary) { word in
                VStack(alignment: .leading) {
                    Text(word.word)
                        .font(.headline)
                    Text("Translation: \(word.translation)")
                    Text("Example: \(word.exampleSentence)")
                        .italic()
                    Text("Difficulty: \(word.difficultyLevel.capitalized)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .onAppear { loadVocabulary() } // ✅ Load words when view appears
    }

    func addNewWord() {
        guard let userID = authManager.user?.id else {
            errorMessage = "🔥 Error: No user found!"
            return
        }

        guard !newWord.isEmpty, !translation.isEmpty, !exampleSentence.isEmpty else {
            errorMessage = "All fields must be filled!"
            return
        }

        FirestoreManager.shared.addVocabularyWord( // ✅ Corrected method call
            userID: userID,
            word: newWord,
            translation: translation,
            exampleSentence: exampleSentence,
            difficultyLevel: difficultyLevel
        ) { error in
            if let error = error {
                errorMessage = "🔥 Failed to add word: \(error.localizedDescription)"
            } else {
                errorMessage = "✅ Word added successfully!"
                newWord = ""
                translation = ""
                exampleSentence = ""
                difficultyLevel = "easy"
                loadVocabulary() // ✅ Reload list after adding
            }
        }
    }

    func loadVocabulary() {
        guard let userID = authManager.user?.id else {
            errorMessage = "🔥 Error: No user found!"
            return
        }

        FirestoreManager.shared.getVocabulary(userID: userID) { words, error in // ✅ Fixed method call
            if let error = error {
                errorMessage = "🔥 Error loading vocabulary: \(error.localizedDescription)"
            } else {
                vocabulary = words ?? []
            }
        }
    }
}
