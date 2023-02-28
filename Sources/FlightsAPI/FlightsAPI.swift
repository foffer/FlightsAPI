import Foundation
import os.log

enum APIError: Error {
    case noParams
    case dateError(String)
}

class FlightAPI {
    
    private let decoder = JSONDecoder()
    private let session = URLSession.shared
    private let logger = Logger(subsystem: "com.cewbed.roster-schedule", category: "flight-api")
    
    static let shared = FlightAPI()
    
    func getAllFlights(for date: Date = Date()) async throws -> [CommonFlight] {
        guard Calendar.current.isDateInToday(date) else {
            throw APIError.dateError("Date must be today, currently the API does not support fetching past or future flights")
        }
        
        async let nhv = getNHVFlights()
        async let bhl = getBHLFlights()
        async let chc = getCHCFlights()
        let newFlights: [[CommonFlight]] = [
            await nhv.map { $0.build() },
            await bhl.map { $0.build() },
            await chc.map { $0.build() }
      ]
        return newFlights.flatMap { $0 }
    }
    
    
    func getNHVFlights() async -> [NHVFlight] {
        let request = request(for: .nhv)
        do {
            let flights: [NHVFlight] = try await data(for: request)
            return flights
        } catch {
            logger.error("Could not get NHV flights: \(error.localizedDescription)")
            return []
        }
        
    }
    
    func getBHLFlights(for date: Date = Date()) async -> [BHLFlight] {
        let df = DateFormatter()
        df.dateFormat = "dd-MMM-yyyy"
        
        let dateString = df.string(from: date)
        let request = request(for: .bristow(baseID: "1", date: dateString))
        logger.info("Getting BHL flights for date: \(dateString)")
        do {
            let flights: [BHLFlight] = try await data(for: request)
            return flights
        } catch {
            logger.error("Could not get BHL flights: \(error.localizedDescription)")
            return []
        }
    }
    
    func getCHCFlights() async -> [CHCFlight] {
        logger.info("Getting CHC flights")
        do {
            async let departureHTML = getCHCHTML(for: .departure)
            async let arrivalHTML = getCHCHTML(for: .arrival)
            
            let parser = HTMLParser()
            let flights = parser.parse(departureHTML: try await departureHTML, arrivalHTML: try await arrivalHTML)
            return flights
        } catch {
            logger.error("Could not get CHC flights: \(error.localizedDescription)")
            return []
        }
    }
    
    enum CHCDepArr: Int {
        case departure = 1
        case arrival = 0
    }
    
    private func getCHCHTML(for depArr: CHCDepArr, country: String = "EG", base: String = "ABZ") async throws -> String {
        let params = createCHCParams(country: country, depArr: depArr.rawValue, base: base)
        var request = request(for: .chc)
        
        request.httpBody = formData(params: params)
        
        request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9", forHTTPHeaderField: "Accept")
        request.addValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await session.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func request(for endpoint: Endpoint) -> URLRequest {
        var urlComps = URLComponents(string: endpoint.url.absoluteString)
        urlComps?.queryItems = endpoint.queryItems
        
        guard let url = urlComps?.url else {
            fatalError("Could not construct URL from components")
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method
        req.addValue("gzip, defalte, br", forHTTPHeaderField: "Accept-Encoding")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        
        return req
    }
    
    private func data<Response: Decodable>(for request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        if let res = response as? HTTPURLResponse {
            logger.info("Request finished with code: \(res.statusCode)")
        }
        
        return try decoder.decode(Response.self, from: data)
    }
    
    private func formData(params: [String:Any]) -> Data? {
        var data = [String]()
        for(key, value) in params {
            data.append(key + "=\(value)")
        }
        return data
            .map { String($0) }
            .joined(separator: "&")
//            .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            .data(using: .utf8)
    }
    
    private func createCHCParams(country: String, depArr: Int, base: String) -> [String: Any] {
        let date = Date()
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: date)
        
        guard let day = comps.day, let month = comps.month, let year = comps.year else {
            return [:]
        }
        
        return [
            "ddlDay":"\(day)",
            "ddlMonth":"\(month)",
            "ddlYear": "\(year)",
            "ddlCountry": country,
            "btGetFlight": "Get+Schedules",
            "rbDeptArr": "\(depArr)",
            "ddlBase": base,
            "__VIEWSTATE":"%2FwEPDwUJOTAzODI4NjQ2DxYGHhNkU2VsZWN0ZWRCYXNlT2ZmU2V0BwAAAAAAAPA%2FHgtEaXNwbGF5TW9kZQIBHgVCYXNlcxQpdEZsaWdodERpc3BsYXlTaXRlLlNlcnZpY2VSZWZlcmVuY2VXQ0YuQmFzZSwgRmxpZ2h0RGlzcGxheVNpdGUsIFZlcnNpb249MS4wLjAuMCwgQ3VsdHVyZT1uZXV0cmFsLCBQdWJsaWNLZXlUb2tlbj1udWxsAzLhBAABAAAA%2F%2F%2F%2F%2FwEAAAAAAAAADAIAAABIRmxpZ2h0RGlzcGxheVNpdGUsIFZlcnNpb249MS4wLjAuMCwgQ3VsdHVyZT1uZXV0cmFsLCBQdWJsaWNLZXlUb2tlbj1udWxsDAMAAABJU3lzdGVtLCBWZXJzaW9uPTQuMC4wLjAsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49Yjc3YTVjNTYxOTM0ZTA4OQUBAAAAKkZsaWdodERpc3BsYXlTaXRlLlNlcnZpY2VSZWZlcmVuY2VXQ0YuQmFzZQgAAAANYmFzZXR5cGVGaWVsZAdpZEZpZWxkDWxhdGl0dWRlRmllbGQObG9uZ2l0dWRlRmllbGQJbmFtZUZpZWxkDnNob3J0Y29kZUZpZWxkE3RpbWV6b25lT2ZmU2V0RmllbGQPUHJvcGVydHlDaGFuZ2VkBAEBAQEBAAQuRmxpZ2h0RGlzcGxheVNpdGUuU2VydmljZVJlZmVyZW5jZVdDRi5CYXNlVHlwZQIAAAAGMVN5c3RlbS5Db21wb25lbnRNb2RlbC5Qcm9wZXJ0eUNoYW5nZWRFdmVudEhhbmRsZXIDAAAAAgAAAAX8%2F%2F%2F%2FLkZsaWdodERpc3BsYXlTaXRlLlNlcnZpY2VSZWZlcmVuY2VXQ0YuQmFzZVR5cGUBAAAAB3ZhbHVlX18ACAIAAAAAAAAABgUAAAADQUJaBgYAAAAJTjU3MTIwNzAwBgcAAAAKVzAwMjExNTQwMAYIAAAADUFCRVJERUVOLERZQ0UGCQAAAARFR1BEAAAAAAAA8D8KCzLeBAABAAAA%2F%2F%2F%2F%2FwEAAAAAAAAADAIAAABIRmxpZ2h0RGlzcGxheVNpdGUsIFZlcnNpb249MS4wLjAuMCwgQ3VsdHVyZT1uZXV0cmFsLCBQdWJsaWNLZXlUb2tlbj1udWxsDAMAAABJU3lzdGVtLCBWZXJzaW9uPTQuMC4wLjAsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49Yjc3YTVjNTYxOTM0ZTA4OQUBAAAAKkZsaWdodERpc3BsYXlTaXRlLlNlcnZpY2VSZWZlcmVuY2VXQ0YuQmFzZQgAAAANYmFzZXR5cGVGaWVsZAdpZEZpZWxkDWxhdGl0dWRlRmllbGQObG9uZ2l0dWRlRmllbGQJbmFtZUZpZWxkDnNob3J0Y29kZUZpZWxkE3RpbWV6b25lT2ZmU2V0RmllbGQPUHJvcGVydHlDaGFuZ2VkBAEBAQEBAAQuRmxpZ2h0RGlzcGxheVNpdGUuU2VydmljZVJlZmVyZW5jZVdDRi5CYXNlVHlwZQIAAAAGMVN5c3RlbS5Db21wb25lbnRNb2RlbC5Qcm9wZXJ0eUNoYW5nZWRFdmVudEhhbmRsZXIDAAAAAgAAAAX8%2F%2F%2F%2FLkZsaWdodERpc3BsYXlTaXRlLlNlcnZpY2VSZWZlcmVuY2VXQ0YuQmFzZVR5cGUBAAAAB3ZhbHVlX18ACAIAAAAAAAAABgUAAAADSFVZBgYAAAAJTjUzMzQyODAwBgcAAAAKVzAwMDIxMDMwMAYIAAAACkhVTUJFUlNJREUGCQAAAARFR05KAAAAAAAA8D8KCzLbBAABAAAA%2F%2F%2F%2F%2FwEAAAAAAAAADAIAAABIRmxpZ2h0RGlzcGxheVNpdGUsIFZlcnNpb249MS4wLjAuMCwgQ3VsdHVyZT1uZXV0cmFsLCBQdWJsaWNLZXlUb2tlbj1udWxsDAMAAABJU3lzdGVtLCBWZXJzaW9uPTQuMC4wLjAsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49Yjc3YTVjNTYxOTM0ZTA4OQUBAAAAKkZsaWdodERpc3BsYXlTaXRlLlNlcnZpY2VSZWZlcmVuY2VXQ0YuQmFzZQgAAAANYmFzZXR5cGVGaWVsZAdpZEZpZWxkDWxhdGl0dWRlRmllbGQObG9uZ2l0dWRlRmllbGQJbmFtZUZpZWxkDnNob3J0Y29kZUZpZWxkE3RpbWV6b25lT2ZmU2V0RmllbGQPUHJvcGVydHlDaGFuZ2VkBAEBAQEBAAQuRmxpZ2h0RGlzcGxheVNpdGUuU2VydmljZVJlZmVyZW5jZVdDRi5CYXNlVHlwZQIAAAAGMVN5c3RlbS5Db21wb25lbnRNb2RlbC5Qcm9wZXJ0eUNoYW5nZWRFdmVudEhhbmRsZXIDAAAAAgAAAAX8%2F%2F%2F%2FLkZsaWdodERpc3BsYXlTaXRlLlNlcnZpY2VSZWZlcmVuY2VXQ0YuQmFzZVR5cGUBAAAAB3ZhbHVlX18ACAIAAAAAAAAABgUAAAADTldJBgYAAAAJTjUyNDAzMjg4BgcAAAAKRTAwMTE2NTgwOAYIAAAAB05PUldJQ0gGCQAAAARFR1NIAAAAAAAA8D8KCxYCAgMPZBYSAgMPEGRkFgECDGQCBQ8QZGQWAQIFZAIHDxBkZBYBAgxkAgsPEA8WBh4ORGF0YVZhbHVlRmllbGQFAmlkHg1EYXRhVGV4dEZpZWxkBQRuYW1lHgtfIURhdGFCb3VuZGdkEBVOCChTZWxlY3QpBkFOR09MQRNBTlRJR1VBIEFORCBCQVJCVURBCUFSR0VOVElOQQlBVVNUUkFMSUEHQVVTVFJJQQpBWkVSQkFJSkFOB0JBSEFNQVMHQkVMR0lVTQVCRU5JTg1CT1VWRVQgSVNMQU5EBkJSQVpJTBFCUlVORUkgREFSVVNTQUxBTQZDQU5BREEOQ0FZTUFOIElTTEFORFMFQ09OR08NQ09URSBEIElWT0lSRQlDWkVDSCBSRVAHREVOTUFSSw1ET01JTklDQU4gUkVQCkVBU1QgVElNT1IRRVFVQVRPUklBTCBHVUlORUENRkFST0UgSVNMQU5EUwZGUkFOQ0UFR0FCT04HR0VPUkdJQQdHRVJNQU5ZBUdIQU5BBkdSRUVDRQlHUkVFTkxBTkQGR1VJTkVBBkdVWUFOQQdIVU5HQVJZB0lDRUxBTkQJSU5ET05FU0lBB0lSRUxBTkQFSVRBTFkHSkFNQUlDQQpLQVpBS0hTVEFOBUtFTllBB0xJQkVSSUEJTElUSFVBTklBCkxVWEVNQk9VUkcGTUFMQVdJCE1BTEFZU0lBBU1BTFRBCk1BVVJJVEFOSUEGTUVYSUNPB01PUk9DQ08KTU9aQU1CSVFVRQdOQU1JQklBC05FVEhFUkxBTkRTCU5JQ0FSQUdVQQdOSUdFUklBBk5PUldBWQtQSElMSVBQSU5FUwZQT0xBTkQLUFVFUlRPIFJJQ08HUk9NQU5JQRNTQUlOVCBLSVRUUyAmIE5FVklTC1NBSU5UIExVQ0lBB1NFTkVHQUwMU09VVEggQUZSSUNBBVNQQUlOCFNVUklOQU1FBlNXRURFTghUQU5aQU5JQQhUSEFJTEFORBFUUklOSURBRCAmIFRPQkFHTwZUVVJLRVkSVFVSS1MgJiBDQUlDT1MgSVNMDlVOSVRFRCBLSU5HRE9NDVVOSVRFRCBTVEFURVMHVVJVR1VBWRFWSVJHSU4gSVNMQU5EUyBVUw5XRVNURVJOIFNBSEFSQQZaQU1CSUEIWklNQkFCV0UVTgItMQJGTgJUQQJTQQFZAkxPAlVCAk1ZAkVCAkRCAkJWAlNCAldCAkNZAk1XAkZDAkRJAkxLAkVLAk1EAldUAkZHAkZSAkxGAkZPAlVHAkVEAkRHAkxHAkJHAkdVAlNZAkxIAkJJAVcCRUkCTEkCTUsCVUECSEsCR0wCRVkCRUwCRlcCV00CTE0CR1ECTU0CR00CRlECRlkCRUgCTU4CRE4CRU4CUlACRVACVEoCTFICVEsCVEwCR08CRkECTEUCU00CRVMCSFQCVlQCVFQCTFQCTUICRUcBSwJTVQJUSQJHUwJGTAJGVhQrA05nZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2cWAQJHZAITDxAPFgYfAwUCaWQfBAUEbmFtZR8FZ2QQFQQIKFNlbGVjdCkNQUJFUkRFRU4sRFlDRQpIVU1CRVJTSURFB05PUldJQ0gVBAItMQNBQloDSFVZA05XSRQrAwRnZ2dnZGQCFQ8PFgIeBFRleHQFElVUQyBPZmZTZXQ6IDFocihzKWRkAhkPDxYCHwYFDURlcGF0dXJlIFRpbWVkZAIlDxYCHgtfIUl0ZW1Db3VudAIEFghmD2QWDgIBDw8WAh8GBQMzMUFkZAIDDw8WAh8GBQUwNzowMGRkAgUPDxYCHwYFFk5FUFRVTkUgRSZQIFVLIExJTUlURURkZAIHDw8WAh8GBSZDeWdudXMgQWxwaGEgLyBDeWdudXMgQnJhdm8gLyBBYmVyZGVlbmRkAgkPDxYGHwYFCERlcGFydGVkHglGb3JlQ29sb3IKJR4EXyFTQgIEZGQCCw8PFgIfBgUFMDY6NTVkZAINDw8WAh8GZWRkAgEPZBYOAgEPDxYCHwYFAzEyWGRkAgMPDxYCHwYFBTA5OjMwZGQCBQ8PFgIfBgUIUGV0cm9mYWNkZAIHDw8WAh8GBRtJc2xhbmQgSW5ub3ZhdG9yIC8gQWJlcmRlZW5kZAIJDw8WBh8GBQhEZXBhcnRlZB8ICiUfCQIEZGQCCw8PFgIfBgUFMTA6MjVkZAINDw8WAh8GZWRkAgIPZBYOAgEPDxYCHwYFAzM4QWRkAgMPDxYCHwYFBTEwOjE1ZGQCBQ8PFgIfBgUFU2hlbGxkZAIHDw8WAh8GBRhCcmVudCBDaGFybGllIC8gQWJlcmRlZW5kZAIJDw8WBh8GBQhEZXBhcnRlZB8ICiUfCQIEZGQCCw8PFgIfBgUFMTA6MDVkZAINDw8WAh8GZWRkAgMPZBYOAgEPDxYCHwYFAzMxQmRkAgMPDxYCHwYFBTE2OjMwZGQCBQ8PFgIfBgUWTkVQVFVORSBFJlAgVUsgTElNSVRFRGRkAgcPDxYCHwYFJkN5Z251cyBCcmF2byAvIEN5Z251cyBBbHBoYSAvIEFiZXJkZWVuZGQCCQ8PFgYfBgUIRGVwYXJ0ZWQfCAolHwkCBGRkAgsPDxYCHwYFBTE2OjM2ZGQCDQ8PFgIfBmVkZAInDw8WAh8GZWRkZIGmsnisaFO2lUC10ScEleaWWmnRynScCAINoLiQ513q",
            "__EVENTVALIDATION": "%2FwEdAKUBapcNtf9V3a7apRH7VQV%2FsluZVBCaaTMDVBUiNx7vpsT4iw87awdD8oX%2Fjw37WbpnCylRSvxRwJgqiQUujUZoSStgIZhikSO49G%2B1fjJ47NbU%2FMwIutVLBQ1T5ZHpozCqsxpEYkRyXDIQFq4zdujjL9YLSw9NEYux7LzeiMrbp0ekDov2K0rW9GWeF%2BAVWJ4sPc5f8X3CsSjLatQmbFN8l6BffKZUV9KrQxt4H1bT%2F%2BR4dw5t3bOEluFfzcLgDQMOKuxABNiwJ1rv88kgiZR%2FoBrTGekNzr3laMH6sSSwxh5suaVXA0AgDKYOOvyXUboNcrQ%2FcR%2BmSwmDCWppd1Fca%2BNFk9cikeuq3dS9CneRe%2B3CbLLhca3BoX3VhNxV5sTl%2FZU9iVS56mbLlSKtOSBC6CiHFWTTu579CpTt3chchocmQ9IxgOkE%2FhfSlF6xADzOIoMAmem%2FlMZ9B%2F%2FdWhkWeJnhz8naYGvzoYrsfHjlzRYKxtenD8jQSQZnXaKoSUN%2F4hbNI9dTKdUjEcwB5xWeWqE2aY9sk8MZO0yYor5Czxkk4%2BFt4QNT6qeGJPKGls0ydgSIGHyITs5RRBxk34JHZPHIH1WY3ZL%2BYSRdqwyal1K%2BCfqMvO%2BYGsFpb%2F3UEq5Wtm55kFoR9breQwbCHLxWdd1SDvEbSr9NN%2FbrPlpTdOYooWlUIHARqr%2FKlwIT6zfnpG616OCgW3hcq9dizqri9yGv9xBWH%2FRg1CVG3qMZcFnmQZ730scTMM9WsMt%2BpAxSOjPHmpHkYSafZpge3N%2BkImavSKQjLb%2FQit3PXqBuwRk5mOjU3jCW914A0FCZYi0KrrCliEvXfc0i7Up5kgUCDVPlW%2F6UxI2DSRVnFP1gwJ%2FPGnbgWJnjpIU%2FMStAcX1awrDBqUFR7PxcDuuwYYJhYjKPCXzDkAvCLcWq%2Ba7ZXYROxencNx9L3uNYT9OeXMYGwWemWeb4KLK%2BbaJ7NKZwPehcMS1yLyZ52cUQpBBi9r6HU8HDoDJVT1J2K%2FeQI4%2BA4pnX0P%2B2bLZvBfOH%2Ft4fWCWAlJYGhvsObwaNWBbmv0kHGaMsr8bAr7t9J86%2Bpu1fdoU6WdnwFP0DXPL1dqxkGIo7FuDy7NXB14avq%2Fb2v7dvS79CQa5ggWUtrK6PFC5GqH6WXxs8JPfC5HROATEan1v%2BEHwdfIYs6w%2BKmqOZx1o56cu0mmjnuz6ZDaiS26P0yHc9g4mdZJS%2FL%2Fp0n%2FrLCQ6UdJYn6PtwhoBlPSSjImVyDMMh8xeYf6PrLVxRbSzohmqClPJvLjTpG%2FVgcnO6NaxnPFA2D2YeTIHMeIaMbuvim%2B7D%2BerG5fSex7bXMQfoQwISULHWwlvaLVAeNBw4DJuQ7IZN3aPTuVdPaBZHGcVVTkj3I9Lz2D8jAvDv4EGvdbJPh%2FY98ZnSZ0bzg9EVrs5u3316oxVgtMDPOZ1VNh6DAmNDi%2FIyp%2FC%2BOiUdV5ByKPCp1UaSMr8EE%2Fx7obZBnl0x0XsTpxmHuhRni18xRHYxeGNi1sajZ2KbhjoXGwhXtpKpljcBaNzM5LuXZMBVmfKyfE3cBLupJA6IwpVl4w7oh06KRntQ3coydH%2FcGAFO6nwok%2FAkptLQpkK2BDDKI%2FLwX192i2za5JgdMdxswOHyJPqi2iyQynnwQb4xuKO2pKeEjrvS8GcMXrT9XLodAX87rIc3iuv6Rq0x86RDDOCQuMIjm3fmQ9RV4yPnVudUdCxxe8GwAgVNZMj%2F0j8WXbWuMLb809t2hBcmzGHdm2FXiWCkKB1TDNNDa7StQNAARpBazOtqvuL4oynplN7ebQkCGrf%2FlygKR%2BsmUI6KerSCSlTAAOHlFPxedESD0RF2R5eJrQCmwJcRZDMfP%2BXcyCt8AOFFThtTftpSYoyfzX%2FUsYts6aaqBARh9OmBw0szmYmLr2kMu6aSUf%2Frpvg1YMcepqtR7TOnmP4QLUi5%2FKWPQIT%2FGqj42w%2FCiCs9u%2BgtMTmbm19O1Egwkzvf0vG0T%2BskZskL6JhT3om60e7HIm8MWsqwhK3wYM8bSHzd3T951R16FQ8cA%2FbGYLW1o5ivDzcLIFE4roV4O50gbHnSsYJnkBSJt9m9P3b9fN35BvfQ2uzZtukSOyKFFWTSgqXM1gQz62wQF918zJaWBd3P%2FngMAY4wrkooKEe01WIieUcet%2F6SikX4ShQ0EF4AarIfbT2YMccyiWJMvIf1bJvz%2FPnvbazV80iCJRGARq7%2FcdWKQjkbeSHud5Y3QU5ssRkid6Kfcyk1vbO1%2FueOQcOfVQSCwzKBG%2FH5DpwQFWvkY3wUshuWt6aIiK6rEmPQ7Xh5bpSbn6LqyoamFIyEuWMQCYAOM7pDlPPj7a3TL%2Bl4KGyMXB6Ts4tlZuC0FB%2FF5RcMf0P8StZmijlxduKY5C5GLXTk9pzxGHN2OAcn3DdyiIUW4rfxWrGceP5EQ4S17rti3WBYGn6NVBkLiMgJBqOR3%2BvvyXzKnoazrbMl%2BLyFU07x651SgouzStcYNViSPaKSr9BsrDK56GRNeBHLTAsz%2Bmg%2BL4spNZIbUIlUELnS%2F4WPrmdhrtwDyYeLdYBK0hHNiUkezaYvyMt070PZRNdesnYIP4305s7ZJCHSDFcsUU6KEIW%2BZShRSJGsZ4OsvnWUM6Klg%2Fhu856251mIvXsjUb3vVQYCUa7%2FA4sMnLBYkFkrcuTJNITRIEOLfVN8xPQyjMkDVCjE5Q5zVH5rkDW6xBZXv5HqlHHsMoNL6o0CDl2oSXd3H7s0Ud2cLfdHHwHadc1pifLFqEyQAL%2FN1yefHjb2m0HWV6M%2FTVTHUOVmGUtTyVBcgr0LRhQtI3Kxq1iODEnVReROUF1xq%2BJ4NCIf5giWuaq%2BE1OkbtC6j1ZTMIGTlDE6H3Mui6zSHJXVcGpyhbkp1Z7csERpSulzFZQkR3iWPHsp5%2FJxdsb%2FIeZ%2B7zJrj%2FExMKhlusU4F7EdOcqYFFRFaAPAXlvl2gel9h3DFfvTXP6HTOyfWQpWPpO6zQ%2FdFV9Y6IP0dXBIBJu8mmVX5NB8YCeSIYsYTZDXBA3KvJDxkxlXb2I9ejv%2BPZwJ%2FfuDov6Ujgbc6m3NPKrIjMvsJ%2BGPtHqNqDcQJFhF9DVg4wkkJvkgHq087TS6ZCsi88aK7jmvXwYLvz6puYe6GIgxd4NwnB66yKrl0UN1gLZeLD0xrwEgdoBI2c9HxfvUECmINeMqLBcNBQFSR6xRUOe2drtuMvf1JOnO9%2FIAGUBctE9cs6Wr%2FNW6cAs65HzWpOJqf%2FA7akdYWhni5GGDBZjzJNdI%2FUVKk%2B7%2F9qq9LIXv%2FxdhsB2L7NShRMMLbg0WDdqA8x9Acs0CkrGRUPM12I%2FpWfVcoStU4Tpozb3xdktwwXdrOW0Jmq1uKPoJ7nINPKCeawXWJm3CVV8B8KmfPTArNd%2B1nbiJDuWIydLuXEkMKFNtO5p8qWus9K4kwzRmhmNheU317KVBwPT0djJfdciCoI3s3QOhNRLqK0oScp1FGW2O%2FucP1fzfqJyBjyX5QdcEgmHsWdA8oXA7zLPoOkQZ3MSd%2BkAbtjzgfiDLSIzIP2g%3D"
        ]
    }
}



