//
//  BookingModel.swift
//  Language App
//
//  Created by Nathan Webster on 3/11/25.
//
import Foundation

struct Booking: Identifiable {
    let id: String
    let studentID: String
    let studentName: String
    let date: String
    let timeSlot: String
    let status: String
}
