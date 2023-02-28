//
//  File.swift
//  
//
//  Created by Christoffer Buusmann on 28/02/2023.
//

import Foundation

enum Endpoint {
    case nhv
    case bristow(baseID: String, date: String)
    case chc
    case airLabs
    
    var url: URL {
        switch self {
        case .nhv:
            return URL(string: "https://flights.nhv.be/api/public/schedule/ABZ")!
        case .bristow:
            return URL(string: "https://www.bristowgroup.com/api/v1/flight-tracker/flights")!
        case .chc:
            return URL(string: "https://aims-scheduler.chc.ca/FlightDisplay.aspx")!
        case .airLabs:
            return URL(string: "https://airlabs.co/api/v9/flights")!
        }
    }
    
    var method: String {
        switch self {
        case .nhv, .bristow(_,_), .airLabs:
            return "GET"
        case .chc:
            return "POST"
        
        }
    }
    
    var queryItems: [URLQueryItem] {
        switch self {
        case .nhv:
            return []
        case .bristow(let baseID, let date):
            return [
                URLQueryItem(name: "basename_id", value: baseID),
                URLQueryItem(name: "date", value: date)
            ]
        case .chc:
            return []
        case .airLabs:
            return []
            
        }
    }
}
