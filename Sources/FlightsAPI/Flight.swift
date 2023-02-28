//
//  Flight.swift
//  Rotor Schedule
//
//  Created by Christoffer Buusmann on 12/06/2022.
//

import Foundation
import SwiftUI

//MARK: - Flight Status
public enum FlightStatus: Equatable, Codable {
    
    
    case delayed
    case onTime
    case preparing
    case cancelled
    case outbound
    case inbound
    case arrived
    case `unknown`(String?)
    
    public var synthesizedRawValue: String {
        switch self {
        case .delayed:
            return "delayed"
        case .onTime:
            return "onTime"
        case .preparing:
            return "preparing"
        case .cancelled:
            return "cancelled"
        case .outbound:
            return "outbound"
        case .inbound:
            return "inbound"
        case .arrived:
            return "arrived"
        case .unknown(let string):
            return string ?? "unknown"
        }
    }

    
    public var label: String {
        switch self {
        case .delayed:
            return "Flight delayed"
        case .onTime:
            return "On Time"
        case .outbound:
            return "Flight outbound"
        case .preparing:
            return "Flight preparing"
        case .inbound:
            return "Flight inbound"
        case .arrived:
            return "Flight arrived"
        case .cancelled:
            return "Flight cancelled"
        case .unknown(let string):
            return string ?? "Unknown"
        }
    }
}
//MARK: - Operator
public enum Operator: String, CaseIterable, Identifiable, RawRepresentable, Codable, Hashable {
    public var id: String { rawValue }
    
    case nhv
    case bhl
    case chc
    case ohs
    
    var shortName: String {
        switch self {
            
        case .nhv:
            return "NHV"
        case .bhl:
            return "BHL"
        case .chc:
            return "CHC"
        case .ohs:
            return "OHS"
        }
    }
    
    var label: String {
        switch self {
            
        case .nhv:
            return "Noordzee Helikopters Vlaanderen"
        case .bhl:
            return "Bristow Helicopters"
        case .chc:
            return "CHC Helicopter Corporation"
        case .ohs:
            return "Offshore Helicopter Services"
        }
    }
}

protocol FlightBuilder {
    func build() -> CommonFlight
    var flightStatus: FlightStatus { get }
}

//MARK: - Flight
protocol Flight: Identifiable {
    var id: String { get }
    var flightNumber: String { get }
    var routing: String { get }
    var routingComponents: [String] { get }
    var flightStatus: FlightStatus { get }
    var `operator`: Operator { get }
    var client: String { get }
    var statusColor: Color { get }
    var std: String { get }
    var eta: String { get }
    var stdDate: Date? { get }
    var atdDate: Date? { get }
    var etaDate: Date? { get }
    
    //MARK: Notification methods
    //
    //    func beginDateForNotification() -> Date
    
}

extension Flight {
    var statusColor: Color {
        switch flightStatus {
        case .delayed:
            return .orange
        case .onTime:
            return .blue
        case .outbound:
            return .blue
        case .preparing:
            return .orange
        case .inbound:
            return .blue
        case .arrived:
            return .green
        case .cancelled:
            return .red
        case .unknown:
            return .brown
        }
    }
    
    var statusSystemIconName: String {
        switch flightStatus {
        case .delayed:
            return "hand.raised"
        case .onTime:
            return "clock.fill"
        case .outbound:
            return "airplane"
        case .preparing:
            return "figure.walk"
        case .inbound:
            return "airplane"
        case .arrived:
            return "airplane.arrival"
        case .cancelled:
            return "exclamationmark.octagon.fill"
        case .unknown:
            return "questionmark.circle.fill"
            
        }
    }
}

//MARK: - Pinned Flights
typealias PinnedFlights = [CommonFlight]
extension PinnedFlights: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let results = try? JSONDecoder().decode(PinnedFlights.self, from: data)
        else {
            return nil
        }
        // Filter out any flights that isn't today
        self = results.filter { $0.isToday }
    }
    
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

//MARK: - Common Flight
public struct CommonFlight: Flight, Codable {
    
    public let id: String
    // Instantiate todays date every time a common flight is created
    // so that we can disregard old pinned flights
    public var date = Date()
    public let flightNumber: String
    public let routing: String
    public let routingComponents: [String]
    public let flightStatus: FlightStatus
    public let `operator`: Operator
    public let client: String
    public let std: String
    public let eta: String
    
    public var ata: String?
    public var atd: String?
    public var stdDate: Date?
    public var atdDate: Date?
    public var etaDate: Date?
    
    public var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    
    
    
    public var isLate: Bool {
        guard let actual = atdDate, let scheduled = stdDate else {
            return false
        }
        return actual > scheduled
    }
    private func hoursMinutesStringToDate(_ string: String) -> Date? {
        let hoursMinutes = string.split(separator: ":").map(String.init).map { try? Int($0, format: .number) }
        guard hoursMinutes.count == 2 else {
            return nil
        }
        
        return Calendar.current.date(bySettingHour: hoursMinutes.first! ?? 0, minute: hoursMinutes.last! ?? 0, second: 0, of: date) ?? date
    }
    
}



struct Flights {
    static let testData: [CommonFlight] = BHLFlight.testData.map { $0.build() }
}
