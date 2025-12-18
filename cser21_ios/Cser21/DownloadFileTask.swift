//
//  DownloadFileTask.swift
//  Cser21
//
//  Created by Hung-Catalina on 3/21/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//
import UIKit
import Foundation
import Alamofire
class DownloadFileTask {
    func getDocumentsDirectory() -> URL {
        //fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    //MARK: - getlist
    func getlist() -> [[String:Any?]]
    {
        var lst = [[String:Any?]]()
        let fileManager = FileManager.default
        let documentsURL = self.getDocumentsDirectory()
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            // process files
            for f in fileURLs
            {
                //fileinfo: name, create, last, len,abspath
                var finfo = [String:Any?]();
                finfo["abspath"] = DownloadFileTask.toLocalSchemeUrl( f.absoluteString)
                finfo["name"] = f.pathComponents.last ?? "";
                
                let attr = try fileManager.attributesOfItem(atPath: f.absoluteURL.path)
                finfo["len"] = attr[FileAttributeKey.size] as! Int64
                finfo["create"] = attr[FileAttributeKey.creationDate] as? Date;
                finfo["last"] = attr[FileAttributeKey.modificationDate] as? Date;
                
                
                lst.append(finfo)
            }
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
        
        return lst
    }
    func toPrivatePrix(absPath: String) -> String {
        
        if(absPath.starts(with: "file:///var/") ){
            return absPath.replacingOccurrences(of: "file:///var/", with: "file:///private/var/")
        }
        
        return absPath
    }
    
    func ddMMyyyyHHmmss(date: Date?) -> String {
        let d = date ?? Date();
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMyyyyHHmmss"
        return formatter.string(from: d);
    }
    
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }

        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
    
    func save(image: UIImage, opt: [String:String]) -> String {
        
        var ext = ".png";
        var pref = "IMG-";
        
        ext = opt["ext"] == ".jpg" ? ".jpg" : ".png"
        pref = opt["pref"]  ?? pref
        
        let max_width = Int().parseAny(any: opt["maxwidth"] ?? "1000")
        let max_height = Int().parseAny(any: opt["maxheight"] ?? "1000")
        let scaleImage = resizeImage(image: image, targetSize: CGSize(width: max_width, height: max_height))
        
        let data = ext == ".jpg" ? scaleImage.jpegData(compressionQuality: 1) : scaleImage.pngData();
        
        let name = pref + ddMMyyyyHHmmss(date: Date()) + ext;
        let filename = getDocumentsDirectory().appendingPathComponent(name)
        
        //let path = filename.path
        
        try? data!.write(to: filename)
        //return "file://private/" + path
        return DownloadFileTask.toLocalSchemeUrl(filename.absoluteString)
       // return toPrivatePrix(absPath: filename.absoluteString);
    }
    
    func saveURL(url: URL?, suffix: String) -> String
    {
        let to = filenameFrom(suffix: suffix);
        do {
            let d = try Data(contentsOf: url!)
            try? d.write(to: to)
        } catch {
            print("Unable to load data: \(error)")
        }
        return DownloadFileTask.toLocalSchemeUrl(to.absoluteString)
    }
    
    func saveURL2(url: URL?, suffix: String) -> String
    {
        let to = filenameFrom(suffix: suffix);
        do {
            let d = try Data(contentsOf: url!)
            try? d.write(to: to)
        } catch {
            print("Unable to load data: \(error)")
        }
        return to.absoluteString
    }
    

    
    
    static func replaceStartWith(str: String, startWidth: String, replace: String) -> String {
        let pref = startWidth;
        let index = str.index(str.startIndex, offsetBy: pref.count)
        let s = str[index...]
        return replace + s;
    }
    //MARK: - (static)toLocalSchemeUrl
    static func toLocalSchemeUrl(_ filename: String) -> String {
       return replaceStartWith(str: filename, startWidth: "file://", replace: "local://")
    }
    static func urlToLocalFileName(_ localUrl: String) -> String {
         return replaceStartWith(str: localUrl, startWidth: "local://", replace: "file://")
    }
    
    static func readData(filePath: String)  -> Data
    {
       // let inp = InputStream(fileAtPath: filePath);
        let path = filePath // or whatever...
        //let currentDirectory = getDocumentsDirectory(DownloadFileTask())
        let absouteURL = URL(fileURLWithPath: path);
        let inp = InputStream(url: absouteURL)
        do{
            return  try Data(reading: inp!)
        }catch{
            //throw  Error21.runtimeError(error.localizedDescription)
            NSLog(error.localizedDescription);
            return Data.init(); //empty
        }
    }
    static func readData2(filePath: String)  -> Data?
    {
       // let inp = InputStream(fileAtPath: filePath);
        let path = filePath // or whatever...
        //let currentDirectory = getDocumentsDirectory(DownloadFileTask())
        let absouteURL = URL(fileURLWithPath: path);
        
        
        let inp = InputStream(url: absouteURL)
        do{
            return  try Data(reading: inp!)
        }catch{
            //throw  Error21.runtimeError(error.localizedDescription)
            NSLog(error.localizedDescription);
            return nil; //empty
        }
    }
    
    func getName(path: String) -> String {
        let a = String(path.split(separator: "?").first!)
        let name = String(a.split(separator: "/").last!)
        return name
    }
    func localToData(filePath: String) -> Data{
        let name = getName(path: filePath)
        let path = getDocumentsDirectory().appendingPathComponent(name)
        
        let inp = InputStream(url: path)
        do{
            return  try Data(reading: inp!)
        }catch{
            //throw  Error21.runtimeError(error.localizedDescription)
            NSLog(error.localizedDescription);
            return Data.init(); //empty
        }
    }
    
    
    //MARK: deletePath
    func deletePath(path: String) -> String
    {
        
        let fn = path.split(separator: "/").last
        //let filename = getDocumentsDirectory().appendingPathComponent(fn);
        var fileUrl = self.getDocumentsDirectory()
        //documentsURL.appendPathComponent(fn!)
        fileUrl.appendPathComponent("" + fn!)
        let fileManager = FileManager.default

        // Delete 'hello.swift' file

        do {
            try fileManager.removeItem(at: fileUrl)
            return "";
        }
        catch let error as NSError {
            NSLog(error.localizedDescription)
            return error.localizedDescription
        }
    }
    
    let cachName: String = "downloadCache"
    
    //MARK: - getCache
    func getCache(url: String) -> String?
    {
        var dic = UserDefaults.standard.dictionary(forKey: cachName);
        if(dic == nil)
        {
            dic = [String:Any]();
        }
        return dic![url] as? String
    }
    func setCache(url: String,localPath: String)
    {
        var dic = UserDefaults.standard.dictionary(forKey: cachName);
        if(dic == nil)
        {
            dic = [String:Any]();
        }
        dic![url] = localPath;
        UserDefaults.standard.set(dic!, forKey: cachName);
    }
    
    //MARK: - clear
    func clear(param: String, callback: @escaping (_ ok: String, _ error: String?) -> ())  {
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let documentsURL = self.getDocumentsDirectory()
            var _error : String? = nil
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                // process files
                for f in fileURLs
                {
                    //fileinfo: name, create, last, len,abspath
                    do {
                        try fileManager.removeItem(at: f)
                       
                    }
                    catch let error as NSError {
                        NSLog(error.localizedDescription)
                        
                    }
                }
            } catch {
                print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
                _error = error.localizedDescription
            }
            // Bounce back to the main thread to update the UI
            DispatchQueue.main.async {
                callback("OK",_error);
                
            }
        }
        
        
        
        
    }
    
    //MARK: - load
    func load(src: String, success: @escaping (_ src: String) -> (),fail: @escaping (_ mess: String) -> ()) {
        //không dùng cache ở đây(dùng localStore ở client)
        
        let destination: DownloadRequest.Destination = { _, _ in
            
            var fn = src.split(separator: "?").first
            fn = fn?.split(separator: "/").last
            
            
            var documentsURL = self.getDocumentsDirectory()
            documentsURL.appendPathComponent(self.ddMMyyyyHHmmss(date: Date()) + "-" + fn!)
           
            
            return (documentsURL, [.removePreviousFile])
        }
        
        let url = URL(string: src)
        if(url == nil){
            fail("URL Wrong format")
            return
        }
        
        AF.download(url!, to: destination)
        
        .downloadProgress(queue: .main, closure: { (progress) in
            //progress closure
            print(progress.fractionCompleted)
        })
//        .validate { request, response, temporaryURL, destinationURL in
//            // Custom evaluation closure now includes file URLs (allows you to parse out error messages if necessary)
//            //GlobalData.sharedInstance.dismissLoader()
//            return .success
//        }
        
        .responseData { response in
            if let destinationUrl = response.fileURL {
                print(destinationUrl)
                
                
                let local = destinationUrl.absoluteString
                //self.setCache(url: src, localPath: local)
                success(local)
               
            } else {
                //GlobalData.sharedInstance.dismissLoader()
                fail("LOI")
            }
        }
    }
   
    
    
    
    //MARK: - toBase64
    func toBase64(src: String?) -> String?
    {
       
        
        var b64: String? = nil
        do{
            var fn = src?.split(separator: "?").first
            fn = fn?.split(separator: "/").last
            var fileUrl = self.getDocumentsDirectory()
            fileUrl.appendPathComponent("" + fn!)
            let data =  try Data(contentsOf: fileUrl)
            b64 = data.base64EncodedString()
        }catch{
            
        }
        return  b64;
    }
    
    //MARK: - getFile
    func getFile(path: String) -> URL {
        
        var fn = path.split(separator: "?").first
        fn = fn?.split(separator: "/").last
        var fileUrl = self.getDocumentsDirectory()
        fileUrl.appendPathComponent("" + fn!)
        return fileUrl
        
    }
    
    //MARK: - GET_TEXT
    func GET_TEXT(path: String) -> String {
        let fileUrl = getFile(path: path)
        
        do {
            return try String(contentsOf: fileUrl, encoding: .utf8)
        }
        catch {/* error handling here */}
        return ""
    }
    
    func filenameFrom(suffix: String) -> URL {
        var documentsURL = self.getDocumentsDirectory()
        documentsURL.appendPathComponent(self.ddMMyyyyHHmmss(date: Date()) + "-" + suffix)
        return documentsURL
    }
}
extension Data {
    init(reading input: InputStream) throws {
        self.init()
        input.open()
        defer {
            input.close()
        }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            if read < 0 {
                //Stream error occured
                throw input.streamError!
            } else if read == 0 {
                //EOF
                break
            }
            self.append(buffer, count: read)
        }
    }
}

