//
//  BHLFlight.swift
//  Rotor Schedule
//
//  Created by Christoffer Buusmann on 12/06/2022.
//

import Foundation
import SwiftUI

struct BHLFlight: Codable, Identifiable {
    let std, flight, company: String
    let eta, status, routing: String
    let atd, ata: String?
    let date = Date()
    
}

extension BHLFlight: FlightBuilder {
    var id: String { std + flight + routing }

    var flightStatus: FlightStatus {
        switch status.lowercased() {
        case "landed": return .arrived
        case "": return .onTime
        case "flight manned", "check-in now", "flight called": return .preparing
        case "outbound": return .outbound
        case "inbound": return .inbound
        case "delayed": return .delayed
        case "cancelled": return .cancelled
        default: return .unknown(status)
        }
    }
    
    func build() -> CommonFlight {
        .init(
            id: std + flight + routing,
            flightNumber: flight,
            routing: routing,
            routingComponents: routing.components(separatedBy: " / "),
            flightStatus: flightStatus,
            operator: .bhl,
            client: company,
            std: std,
            eta: eta,
            atd: atd,
            stdDate: stdDate,
            atdDate: atdDate,
            etaDate: etaDate
        )
    }
    
    var stdDate: Date? {
        hoursMinutesStringToDate(std)
    }
    
    var atdDate: Date? {
        guard let atd = atd else { return nil }
        return hoursMinutesStringToDate(atd)
    }
    
    var etaDate: Date? {
        hoursMinutesStringToDate(eta)
    }
    
    private func hoursMinutesStringToDate(_ string: String) -> Date? {
        let hoursMinutes = string.split(separator: ":").map(String.init).map { try? Int($0, format: .number) }
        guard hoursMinutes.count == 2 else {
            return nil
        }
        
        return Calendar.current.date(bySettingHour: hoursMinutes.first! ?? 0, minute: hoursMinutes.last! ?? 0, second: 0, of: date) ?? date
    }
}

private let decoder = JSONDecoder()
extension BHLFlight {
    static let testData: [BHLFlight] = [
        [
            "std": "07:00",
            "atd": "07:02",
            "flight": "76A",
            "company": "REPSOL SINOPEC RESOURCES UK LTD",
            "eta": "09:39",
            "status": "Landed",
            "routing": "EGPD / FUL / EGPD"
        ],
        [
            "std": "07:00",
            "atd": "07:18",
            "flight": "60A",
            "company": "BP EXPLORATION OPERATING COMPANY LI",
            "eta": "10:33",
            "status": "Landed",
            "routing": "EGPD / EGPA / PFOIN / EGPB"
        ],
        [
            "std": "07:10",
            "atd": "07:08",
            "flight": "76M",
            "company": "REPSOL SINOPEC RESOURCES UK LTD",
            "eta": "09:52",
            "status": "Inbound",
            "routing": "EGPD / AUKA / EGPD"
        ],
        [
            "std": "07:15",
            "atd": "07:28",
            "flight": "43N",
            "company": "CHRYSAOR PETROLEUM COMPANY UK LTD",
            "eta": "09:54",
            "status": "Outbound",
            "routing": "EGPD / EVER / EGPD"
        ],
        [
            "std": "07:30",
            "atd": "07:41",
            "flight": "78C",
            "company": "BP EXPLORATION OPERATING COMPANY LI",
            "eta": "10:12",
            "status": "Delayed",
            "routing": "EGPD / XSZP / EGPD"
        ],
        [
            "std": "08:15",
            "atd": "09:32",
            "flight": "48D",
            "company": "CHRYSAOR PETROLEUM COMPANY UK LTD",
            "eta": "12:32",
            "status": "Landed",
            "routing": "EGPD / JUDY / JASM / EGPD"
        ],
        [
            "std": "09:00",
            "atd": "08:54",
            "flight": "61E",
            "company": "HURRICANE ENERGY PLC",
            "eta": "12:11",
            "status": "cancelled",
            "routing": "EGPD / AMIZ / EGPD"
        ],
        [
            "std": "11:00",
            "atd": "11:03",
            "flight": "62G",
            "company": "CHRYSAOR PETROLEUM COMPANY UK LTD",
            "eta": "13:25",
            "status": "Landed",
            "routing": "EGPD / BRITP / EGPD"
        ],
        [
            "std": "11:00",
            "atd": "11:14",
            "flight": "51F",
            "company": "REPSOL SINOPEC RESOURCES UK LTD",
            "eta": "13:54",
            "status": "Landed",
            "routing": "EGPD / ARBTH / MONTA / EGPD"
        ],
        [
            "std": "11:10",
            "atd": "10:25",
            "flight": "45B",
            "company": "REPSOL SINOPEC RESOURCES UK LTD",
            "eta": "12:46",
            "status": "Landed",
            "routing": "EGPD / PIPER / EGPD"
        ],
        [
            "std": "11:15",
            "atd": "13:03",
            "flight": "78J",
            "company": "BP EXPLORATION OPERATING COMPANY LI",
            "eta": "15:24",
            "status": "Landed",
            "routing": "EGPD / XSZP / EGPD"
        ],
        [
            "std": "14:00",
            "atd": "13:49",
            "flight": "48K",
            "company": "CHRYSAOR PETROLEUM COMPANY UK LTD",
            "eta": "16:55",
            "status": "Landed",
            "routing": "EGPD / MINN / EN120 / EGPD"
        ],
        [
            "std": "14:30",
            "atd": "13:10",
            "flight": "45L",
            "company": "REPSOL SINOPEC RESOURCES UK LTD",
            "eta": "15:16",
            "status": "Landed",
            "routing": "EGPD / CLAYM / EGPD"
        ],
        [
            "std": "14:45",
            "atd": "14:23",
            "flight": "45H",
            "company": "REPSOL SINOPEC RESOURCES UK LTD",
            "eta": "16:43",
            "status": "Inbound",
            "routing": "EGPD / PIPER / SALT / EGPD"
        ]
    ]
        .map { try! JSONSerialization.data(withJSONObject: $0) }
        .compactMap { try? decoder.decode(BHLFlight.self, from: $0) }
    
}
