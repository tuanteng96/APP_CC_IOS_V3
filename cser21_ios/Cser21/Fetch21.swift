//
//  Fetch21.swift
//  Cser21
//
//  Created by Hung-Catalina on 4/22/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//
import Alamofire
import Foundation
class Fetch21{
    func fetch(url: String) -> Void{
       
        URLSession.shared.dataTask(with: URL(string: url)!) { (data: Data?,response: URLResponse?,error: Error?) in
           
        }.resume()
    }
}
