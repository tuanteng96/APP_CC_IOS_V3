//
//  Noti21.swift
//  Cser21
//
//  Created by Hung-Catalina on 4/8/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//

import Foundation
class Noti21 : Codable {
    var notification: Notification21?
    var data: [String: String]?
    enum CodingKeys: String, CodingKey {
        case notification
        case data
        
    }
    init()
    {
        
    }
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        notification = try values.decode(Notification21.self, forKey: .notification)
        if( values.contains(CodingKeys.data))
        {
            data = [String:String]()
            let d = try values.decode([String: EveryThing].self, forKey: .data)
            for (k, v) in d{
                // data![k] = try  v.value?.decode(String.self)
                data![k] =  String(describing: v.value!)
            }
        }
        
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(notification, forKey: .notification)
        var _data = [String:String?]()
        for (k, v) in data ?? [String:Any?](){
            _data[k] = v as? String?
        }
        try container.encode(_data, forKey: .data)
    }
}
class Notification21: Codable
{
    var title: String?
    var body: String?
    var sound: String?
    var subtitle: String?
    
}
class EveryThing: Codable
{
    var value: Any? = nil
    init()
    {
        
    }
    required init(from decoder: Decoder) throws {
        var object: Any? = nil
        let container = try decoder.singleValueContainer()
        if(object == nil)
        {
            do {
                try object = container.decode(Bool.self)
            }
            catch{
                
            }
        }
        if(object == nil)
        {
            do {
                try object = container.decode(Int.self)
            }
            catch{
                
            }
        }
        if(object == nil)
        {
            do {
                try object = container.decode(Int8.self)
            }
            catch{
                
            }
        }
        
        if(object == nil)
        {
            do {
                try object = container.decode(Int16.self)
            }
            catch{
                
            }
        }
        if(object == nil)
        {
            do {
                try object = container.decode(Int32.self)
            }
            catch{
                
            }
        }
        if(object == nil)
        {
            do {
                try object = container.decode(Int64.self)
            }
            catch{
                
            }
        }
        if(object == nil)
        {
            do {
                try object = container.decode(Double.self)
            }
            catch{
                
            }
        }
        if(object == nil)
        {
            do {
                try object = container.decode(String.self)
            }
            catch{
                
            }
        }
        
        if(object == nil)
        {
            do {
                try object = container.decode(UInt.self)
            }
            catch{
                
            }
        }
        if(object == nil)
        {
            do {
                try object = container.decode(UInt8.self)
            }
            catch{
                
            }
        }
        
        if(object == nil)
        {
            do {
                try object = container.decode(UInt16.self)
            }
            catch{
                
            }
        }
        if(object == nil)
        {
            do {
                try object = container.decode(UInt32.self)
            }
            catch{
                
            }
        }
        
        if(object == nil)
        {
            do {
                try object = container.decode(UInt64.self)
            }
            catch{
                
            }
        }
        value = object
    }
    enum CodingKeys: String, CodingKey {
        case value
        
        
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("Forget Me!", forKey: .value)
        
    }
    

}


