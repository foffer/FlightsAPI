//
//  File.swift
//  
//
//  Created by Christoffer Buusmann on 28/02/2023.
//

import Foundation
import SwiftSoup

struct CHCFlightRow {
    var flightNumber: String?
    var arrDept: String?
    var client: String?
    var routing: String?
    var comments: String?
    var revised: String?
    var status: String?
}

class HTMLParser {
    
    //    typealias CHCFlightRow = (flightID: String, std: String, client: String, routing: String)
    
    func parse(departureHTML: String, arrivalHTML: String) -> [CHCFlight] {
        let tableRowsDepartures = getTableRows(from: departureHTML)
        let tableRowsArrivals = getTableRows(from: arrivalHTML)
        
        let departures = extractRowData(for: tableRowsDepartures)
        let arrivals = extractRowData(for: tableRowsArrivals)
        let matched = departures.map { departure -> CHCFlight in
            if let arrival = arrivals.first(where: { arrival in arrival.flightNumber == departure.flightNumber }) {
                return .init(
                    std: departure.arrDept ?? "N/A",
                    eta: arrival.revised ?? arrival.arrDept ?? "N/A",
                    flightNumber: departure.flightNumber ?? "N/A",
                    client: departure.client ?? "N/A",
                    routing: departure.routing ?? "N/A",
                    status: (arrival.status == "OnTime" ? departure.status : arrival.status) ?? "N/A"
                )
            } else {
                return .init(
                    std: departure.arrDept ?? "N/A",
                    eta: "N/A",
                    flightNumber: departure.flightNumber ?? "N/A/",
                    client: departure.client ?? "N/A",
                    routing: departure.routing ?? "N/A",
                    status: departure.status ?? "N/A"
                )
            }
            
        }
        return matched
        
    }
    
    private func extractRowData(for elements: Elements?) -> [CHCFlightRow] {
        guard let elements = elements else { return [] }
        var flights: [CHCFlightRow] = []
        for element in elements {
            
            var flight: CHCFlightRow = .init()
            for e in try! element.getElementsByTag("span") {
                
                if e.id().contains("FlightNumber") {
                    flight.flightNumber = e.textNodes().map { $0.text() }.first
                } else if e.id().contains("ArrDept") {
                    flight.arrDept = e.textNodes().map { $0.text() }.first
                } else if e.id().contains("Customer") {
                    flight.client = e.textNodes().map { $0.text() }.first
                } else if e.id().contains("Routing") {
                    flight.routing = e.textNodes().map { $0.text() }.first
                } else if e.id().contains("Status") {
                    // The Status field has a style attr attached to it which wraps in in a <font> tag for some reason
                    flight.status = try? e.getElementsByTag("font").get(0).textNodes().map { $0.text() }.first
                } else if e.id().contains("RevTime") {
                    flight.revised = e.textNodes().map { $0.text() }.first
                }
            }
            guard flight.flightNumber != nil else { continue }
            flights.append(flight)
        }
        return flights
    }
    
    private func getTableRows(from html: String) -> Elements? {
        let doc = try! SwiftSoup.parse(html)
        let body = doc.body()
        let table = try? body?.getElementById("Table1")
        let tableRows = try? table?.getElementsByTag("tr")
        return tableRows
    }
}
