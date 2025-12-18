//
//  SERVER_NOTI.swift
//  Cser21
//
//  Created by Hung-Catalina on 4/8/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//

import Foundation
import UserNotifications
import Alamofire
class SERVER_NOTI{
    var app21: App21?
    
    func toUrlWithsParams(url: String, params: [String:String]) -> String {
        var j = url.contains("?")  ?  "&" : "?";
        var c = "";
        var s = url ;
        
        for (k,v) in params
        {
            if(j != "")
            {
                s += j;
                j = "";
            }
            s += c + k + "=" + v;
            c = "&";
        }
        
        return  s;
    }
    
    //MARK: - noti
    func noti(noti21: Noti21) -> Void {
        //
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert,.sound]) { (granted, error) in
            //
        }
        //
        let content = UNMutableNotificationContent()
        content.title = (noti21.notification?.title!)!
        content.body = (noti21.notification?.body!)! as String
        content.subtitle = (noti21.notification?.subtitle!)! as String
        content.userInfo = [String:String]()
        if((noti21.data) != nil){
            for item in noti21.data! {
                content.userInfo[item.key] = item.value
            }
        }
        
        
        content.categoryIdentifier = "App21CustomPush"
        content.sound = UNNotificationSound.default
        
        //largeImage
        let largeIcon = content.userInfo["largeIcon"]
        if largeIcon != nil, let fileUrl = URL(string: largeIcon! as! String) {
            
            guard let imageData = NSData(contentsOf: fileUrl) else {
                return
            }
            
            let fileIdentifier = DownloadFileTask().getName(path: fileUrl.absoluteString)
            guard let attachment = saveImageToDisk(fileIdentifier: fileIdentifier, data: imageData, options: nil) else {
                return
            }
            
            content.attachments = [ attachment ]
        }
        
        //
        let delay = Int().parseDicKey(data: noti21.data, key: "delay", df: 0)
        
        //
        var trigger : UNCalendarNotificationTrigger? = nil
        if(delay  > 0){
            let date = Date().addingTimeInterval(Double(delay))
            let dateComponent = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponent , repeats: false)
            
        }
        
        //
        let uuid = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuid, content: content, trigger: trigger)
        
        //
        center.add(request) { (error) in
            //
        }
    }
    func saveImageToDisk(fileIdentifier: String, data: NSData, options: [NSObject : AnyObject]?) -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        let folderName = ProcessInfo.processInfo.globallyUniqueString
        let folderURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(folderName, isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: folderURL!, withIntermediateDirectories: true, attributes: nil)
            let fileURL = folderURL?.appendingPathComponent(fileIdentifier)
            try data.write(to: fileURL!, options: [])
            let attachment = try UNNotificationAttachment(identifier: fileIdentifier, url: fileURL!, options: options)
            return attachment
        } catch let error {
            print("error \(error)")
        }
        
        return nil
    }
    
    func run(result: Result, callback: @escaping (Error?) -> ()) -> Void{
        do{
            let decoder = JSONDecoder()
            let config = try decoder.decode(SERVER_NOTI_Config.self, from: result.params!.data(using: .utf8)!)
            runBackground(config: config, callback: callback)
        }
        catch{
            callback(error)
        }
    }
    
    //MARK: - runBackground
    func runBackground(config: SERVER_NOTI_Config,callback: @escaping (Error?) -> () ) -> Void {
        do{
            
            if(!config.enable)
            {
                return
            }
            
            let url = URL(string: toUrlWithsParams(url: config.server, params: config.serverParams!))
            let text = try String(contentsOf: url!, encoding: .utf8)
            
            
            let parser = JSON.parse(Response.self, from: text)
            if(parser.1 != nil)
            {
                throw Error21.runtimeError(parser.1!)
            }
            
            let rsp =  parser.0 ?? Response()
            
            let data = rsp.data ?? ResponseData()
            let notis = data.notis ?? [Noti21]()
            //notis
            for noti21 in notis{
                noti(noti21: noti21!)
            }
            //detechLocation
            let detectLocation = data.detechLocation ?? DetechLocation()
            if detectLocation.enable {
                let loc21 = Location21();
                loc21.SendTo(receiver: detectLocation.receiver)
            }
            
             callback(nil)
        }catch{
            NSLog("AAAA:" + error.localizedDescription)
            callback(error)
        }
    }
    
    static let BackgroundFetchConfig = "BackgroundFetchConfig"
    
    //MARK: - runBackgroundFetch
    func runBackgroundFetch() -> Void {
        let _config = UserDefaults.standard.string(forKey: SERVER_NOTI.BackgroundFetchConfig)
        if(_config != nil && _config != "")
        {
            
            let parser = JSON.parse(SERVER_NOTI_Config.self, from: _config!);
            
            if(parser.0 != nil)
            {
                runBackground(config: parser.0!) { (error) in
                    
                }
            }
        }
        
    }
    
}
class SERVER_NOTI_Config : Codable{
    var  enable: Bool = false;
    var  intervalMillis: Int = 1000 * 60 * 15;
    var  server: String = "";
    var  serverParams: [String:String]? = nil;
}
class ResponseData : Codable {
    var notis: [Noti21?]? = nil
    var detechLocation: DetechLocation? = nil
}
class Response : Codable {
    var  success: Bool = false
    var  data: ResponseData?
    
    
}
class DetechLocation : Codable{
    var enable: Bool = false
    var receiver: String = ""
}
