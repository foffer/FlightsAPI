//
//  CHCFlight.swift
//  Rotor Schedule
//
//  Created by Christoffer Buusmann on 19/06/2022.
//

import Foundation

struct CHCFlight: Identifiable {
    var id: String { flightNumber }
    let std: String
    let eta: String
    let flightNumber: String
    let client: String
    let routing: String
    var comments: String = ""
    var revised: String = ""
    let status: String
}

extension CHCFlight: FlightBuilder {
    func build() -> CommonFlight {
        return .init(id: id,
              flightNumber: flightNumber,
              routing: routing,
             routingComponents: routing.components(separatedBy: " / "),
              flightStatus: flightStatus,
              operator: .chc,
              client: client,
              std: std,
              eta: eta
        )
    }
    
    var flightStatus: FlightStatus {
        switch status.lowercased() {
        case "departed": return .outbound
        case "ontime": return .onTime
        case "arrived": return .arrived
        case "cancelled": return .cancelled
        case "inbound": return .inbound
        case "delayed": return .delayed
        default: return .unknown(status)
        }
    }
    
    
}
