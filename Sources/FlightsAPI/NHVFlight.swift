//
//  NHVFlight.swift
//  Rotor Schedule
//
//  Created by Christoffer Buusmann on 12/06/2022.
//

import Foundation
struct NHVFlight: Codable, Identifiable {
    
    private var iso8601DateFormatter: ISO8601DateFormatter {
        let df = ISO8601DateFormatter()
        df.formatOptions.insert(.withFractionalSeconds)
        return df
    }
    
    let id, model, flightNumber, customer: String
    let scheduleDepartureTime, scheduleArrivalTime: String
    let flightRouting: [Routing]
    let status, welcomeClass, isDelayedClassName, arrivalTime: String
    let departureTime: String

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case model = "Model"
        case flightNumber = "FlightNumber"
        case customer = "Customer"
        case scheduleDepartureTime = "ScheduleDepartureTime"
        case scheduleArrivalTime = "ScheduleArrivalTime"
        case flightRouting = "Routing"
        case status = "Status"
        case welcomeClass = "Class"
        case isDelayedClassName, arrivalTime, departureTime
    }
}

// MARK: - Routing
struct Routing: Codable {
    let place, placeName: String

    enum CodingKeys: String, CodingKey {
        case place = "Place"
        case placeName = "PlaceName"
    }
}

extension NHVFlight: FlightBuilder {
    var routing: String {
        flightRouting
            .map { $0.place }
            .joined(separator: " - ")
    }
    
    var flightStatus: FlightStatus {
        switch status.lowercased() {
        case "departed": return .outbound
        case "on-time": return .onTime
        case "boarding": return .preparing
        case "arrived": return .arrived
        case "cancelled": return .cancelled
        case "inbound": return .inbound
        case "delayed": return .delayed
        default: return .unknown(status)
        }
    }
    
    func build() -> CommonFlight {
        .init(
            id: id,
            flightNumber: flightNumber,
            routing: routing,
            routingComponents: routing.components(separatedBy: " - "),
            flightStatus: flightStatus,
            operator: .nhv,
            client: customer,
            std: std,
            eta: eta,
            stdDate: stdDate,
            atdDate: atdDate,
            etaDate: etaDate
        )
    }
    
    
    var std: String {
        let df = DateFormatter()
        guard let date = iso8601DateFormatter.date(from: scheduleDepartureTime) else {
            
            return "N/A"
        }
        df.timeStyle = .short
        return df.string(from: date)
        
    }
    var eta: String {
        let df = DateFormatter()
        guard let date = iso8601DateFormatter.date(from: scheduleArrivalTime) else {
            return "N/A"
        }
        df.timeStyle = .short
        return df.string(from: date)
    }
    var stdDate: Date? { iso8601DateFormatter.date(from: scheduleDepartureTime) }
    var atdDate: Date? { iso8601DateFormatter.date(from: departureTime) }
    var etaDate: Date? { iso8601DateFormatter.date(from: scheduleArrivalTime) }
}

private let decoder = JSONDecoder()
extension NHVFlight {
    static let testData: [NHVFlight] = [
        [
          "ID": "42817ea0-d8f6-11ec-9514-e3e23b01f68a",
          "Model": "AW169",
          "FlightNumber": "SEP900G",
          "Customer": "Spirit Energy",
          "ScheduleDepartureTime": "2022-06-12T07:27:00.000Z",
          "ScheduleArrivalTime": "2022-06-12T08:12:00.000Z",
          "Routing": [
            [
              "Place": "CPC1",
              "PlaceName": "CPC-1"
            ],
            [
              "Place": "DP8",
              "PlaceName": "DP-8"
            ],
            [
              "Place": "CPC1",
              "PlaceName": "CPC-1"
            ],
            [
              "Place": "DPPA",
              "PlaceName": "DPPA (North Morecambe)"
            ]
          ],
          "Status": "arrived",
          "Class": "default",
          "isDelayedClassName": "error",
          "arrivalTime": "2022-06-12T08:39:00.000Z",
          "departureTime": "2022-06-12T07:27:00.000Z"
        ],
        [
          "ID": "479f4f20-d8f6-11ec-9514-e3e23b01f68a",
          "Model": "AW169",
          "FlightNumber": "ENI EXINT3",
          "Customer": "ENI UK - Adhoc",
          "ScheduleDepartureTime": "2022-06-12T08:57:00.000Z",
          "ScheduleArrivalTime": "2022-06-12T09:42:00.000Z",
          "Routing": [
            [
              "Place": "Douglas",
              "PlaceName": "Douglas"
            ],
            [
              "Place": "CNWY",
              "PlaceName": "Conwy"
            ]
          ],
          "Status": "arrived",
          "Class": "default",
          "isDelayedClassName": "error",
          "arrivalTime": "2022-06-12T10:03:00.000Z",
          "departureTime": "2022-06-12T08:57:00.000Z"
        ],
        [
          "ID": "59da3b10-ea20-11ec-ab34-31b7fb768d01",
          "Model": "AW169",
          "FlightNumber": "SEP600G",
          "Customer": "Spirit Energy",
          "ScheduleDepartureTime": "2022-06-12T10:21:00.000Z",
          "ScheduleArrivalTime": "2022-06-12T11:06:00.000Z",
          "Routing": [
            [
              "Place": "CPC1",
              "PlaceName": "CPC-1"
            ]
          ],
          "Status": "departed",
          "Class": "default",
          "isDelayedClassName": "error",
          "arrivalTime": "2022-06-12T10:58:00.000Z",
          "departureTime": "2022-06-12T10:21:00.000Z"
        ],
        [
          "ID": "5f66f4a0-d8f6-11ec-9514-e3e23b01f68a",
          "Model": "AW169",
          "FlightNumber": "SEP950G",
          "Customer": "Spirit Energy",
          "ScheduleDepartureTime": "2022-06-12T16:05:00.000Z",
          "ScheduleArrivalTime": "2022-06-12T17:05:00.000Z",
          "Routing": [
            [
              "Place": "CPC1",
              "PlaceName": "CPC-1"
            ],
            [
              "Place": "DP8",
              "PlaceName": "DP-8"
            ],
            [
              "Place": "CPC1",
              "PlaceName": "CPC-1"
            ]
          ],
          "Status": "departed",
          "Class": "default",
          "isDelayedClassName": "error",
          "arrivalTime": "2022-06-12T16:57:00.000Z",
          "departureTime": "2022-06-12T16:07:00.000Z"
        ],
        [
          "ID": "584257a0-d8f6-11ec-9514-e3e23b01f68a",
          "Model": "AW169",
          "FlightNumber": "ENI EXINT4",
          "Customer": "ENI UK - Adhoc",
          "ScheduleDepartureTime": "2022-06-12T17:15:00.000Z",
          "ScheduleArrivalTime": "2022-06-12T18:00:00.000Z",
          "Routing": [
            [
              "Place": "CNWY",
              "PlaceName": "Conwy"
            ],
            [
              "Place": "Douglas",
              "PlaceName": "Douglas"
            ]
          ],
          "Status": "on-time",
          "Class": "default",
          "isDelayedClassName": "",
          "arrivalTime": "2022-06-12T18:07:00.000Z",
          "departureTime": "2022-06-12T17:15:00.000Z"
        ],
        [
          "ID": "3ab21220-ea4e-11ec-a4c2-59b83240ecfe",
          "Model": "AW169",
          "FlightNumber": "SEP610G",
          "Customer": "Spirit Energy",
          "ScheduleDepartureTime": "2022-06-12T18:25:00.000Z",
          "ScheduleArrivalTime": "2022-06-12T19:00:00.000Z",
          "Routing": [
            [
              "Place": "DPPA",
              "PlaceName": "DPPA (North Morecambe)"
            ]
          ],
          "Status": "arrived",
          "Class": "default",
          "isDelayedClassName": "error",
          "arrivalTime": "2022-06-12T19:05:00.000Z",
          "departureTime": "2022-06-12T18:24:00.000Z"
        ]
      ]
        .map { try! JSONSerialization.data(withJSONObject: $0) }
            .compactMap { try? decoder.decode(NHVFlight.self, from: $0) }
}
