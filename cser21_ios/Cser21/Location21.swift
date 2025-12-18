//
//  Location21.swift
//  Cser21
//
//  Created by Hung-Catalina on 4/22/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//

import Foundation
import CoreLocation

protocol GPSLocationDelegate {
    func fetchedLocationDetails(location: CLLocation, countryCode: String, city: String)
    func failedFetchingLocationDetails(error: Error)
}
class Location21 : GPSLocationDelegate{
    
    
    typealias completionHanlder = (_ lat: Double, _ lng: Double) -> Void
    var completion: completionHanlder?
    var delegate: GPSLocationDelegate?
    func getLocation(completion: (_ lat: Double, _ lng: Double) -> Void) {
        let locManager = CLLocationManager()
        var currentLocation: CLLocation!
        locManager.desiredAccuracy = kCLLocationAccuracyBest

        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways) {

        currentLocation = locManager.location

        let latitude = currentLocation.coordinate.latitude
        let longitude = currentLocation.coordinate.longitude
        let location = CLLocation(latitude: currentLocation.coordinate.latitude, longitude: currentLocation.coordinate.longitude)

        fetchCountryAndCity(location: location, completion: { countryCode, city in
            self.delegate?.fetchedLocationDetails(location: location, countryCode: countryCode, city: city)
        }) { self.delegate?.failedFetchingLocationDetails(error: $0) }

       

        completion(latitude, longitude)  // your block of code you passed to this function will run in this way

       }

    }
    func fetchCountryAndCity(location: CLLocation, completion: @escaping (String, String) -> (), errorHandler: @escaping (Error) -> ()) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                debugPrint(error)
                errorHandler(error)
            } else if let countryCode = placemarks?.first?.isoCountryCode,
                let city = placemarks?.first?.locality {
                completion(countryCode, city)
            }
        }
    }
    func fetchedLocationDetails(location: CLLocation, countryCode: String, city: String) {
        
    }
    
    func failedFetchingLocationDetails(error: Error) {
        
    }
    
    func SendTo(receiver: String) -> Void
    {
        getLocation { (lat: Double,lng: Double) in
            //
            //print(lat, lng)
            var info = ""
            info += "lat:" + String(lat)
            info += ",lng:" + String(lng)
            var p = [String:String]()
            p["ClientValue"] = info
            p["info"] = App21.OS_INFO()
            let url = WebControl.toUrlWithsParams(url: receiver, params: p)
            Fetch21().fetch(url: url)
            
            
        }
    }
}
