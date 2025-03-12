//
//  BookingModel.swift
//  Language App
//
//  Created by Nathan Webster on 3/11/25.
//
import Foundation

struct Booking: Identifiable, Codable {
    var id: String
    var studentID: String
    var studentName: String
    var tutorID: String
    var tutorName: String // ✅ Added this field
    var date: String
    var timeSlot: String
    var status: String
}

