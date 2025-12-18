//
//  X_GET_OR_CACHED.swift
//  ezsspa
//
//  Created by Admin on 21/10/2024.
//  Copyright © 2024 High Sierra. All rights reserved.
//

import Foundation

class GetORCached: NSObject
{
    var app21: App21? = nil;
    var result: Result? = nil;
    let fileManage = FileManager.default;
    @objc func getPath(url: String) -> String?
    {
        let separators = CharacterSet(charactersIn: "\\/:");
        var segs = url.components(separatedBy: separators);
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        {
            var i: Int = 0;
            var path: String = "";
            var folder: String = "";
            repeat
            {
                var x = segs[i];
                x = x.trimmingCharacters(in: CharacterSet(charactersIn: " "));
                if( x == "")
                {
                    i += 1;
                    continue;
                }
                path = path + "/" + segs[i];
                
                let dirPath = dir.appendingPathComponent(path)
                if(!fileManage.fileExists(atPath: dirPath.path))
                {
                    do{
                        let  x: () = try fileManage.createDirectory(atPath: dirPath.path, withIntermediateDirectories: false);
                    }catch{
                        if(result != nil && app21 != nil)
                        {
                            //cả 2 sẽ null  khi gọi downUrl độc lập
                            result?.data = JSON( error.localizedDescription);
                            result?.success = false;
                            app21?.App21Result(result: result!);
                        }
                        
                    }
                    
                }
                folder = dirPath.path;
                i+=1;
            }
            while i < segs.count - 1;
            return path + "/" + segs[segs.count - 1]
        }
        else
        {
            return nil;
        }
        
        
    }
    
    func downUrl(urlStr: String?) -> DownUrlResult?
    {
        var path = getPath(url: urlStr!);
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        {
            let filePath = dir.appendingPathComponent(path!)
            let dataFromURL = NSData(contentsOf: URL(string: urlStr!)!)
            do {
                try  dataFromURL?.write(toFile: filePath.path);
                
                var rs = DownUrlResult();
                rs.path = path;
                rs.absPath =  filePath;
                return rs;
            }catch{
                
            }
        }
        return nil;
    }
    
    @objc func down(urlStr: String?, savePath: String, result: Result, app21: App21, returnType: Int) -> Void
    {
        //var d = EZDownloader();
        //d.load(URL: URL(string: urlStr!)!);
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        {
            let filePath = dir.appendingPathComponent(savePath)
            let dataFromURL = NSData(contentsOf: URL(string: urlStr!)!)
            do {
                try  dataFromURL?.write(toFile: filePath.path);
                response(file: savePath, returnType: returnType, result: result, app21: app21)
                
            }catch{
                result.success = false;
                result.data = JSON( error.localizedDescription);
                app21.App21Result(result: result)
            }
        }
        
    
    }
    
    @objc func getAbsPath(relPath: String?) -> URL?
    {
        if(relPath == nil) {
            return nil;
        }
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        {
            return dir.appendingPathComponent(relPath!)
        }else{
            return nil
        }
        
    }
    
    @objc  func response(file: String, returnType: Int, result: Result, app21: App21) -> Void {
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        {
            let filePath = dir.appendingPathComponent(file)
            switch returnType{
            case 0:
                result.data = JSON(filePath.path)
                break;
            case 1:
                do{
                    let text = try String(contentsOf: filePath, encoding: .utf8)
                    result.data = JSON(text);
                }catch{
                    
                }
                break;
            default:
                result.data = JSON(filePath.path)
                break;
            }
        }
        
        
        result.success = true;
        app21.App21Result(result: result);
    }
    
    @objc func handle(url: String, type: Int, returnType: Int, result: Result, app21: App21) -> Void
    {
        self.app21 = app21;
        self.result = result;
        var path = getPath(url: url);
        
        //var filePath = NSURL(string: path!);
        
        switch type
        {
        case 0:
            //get and cached
            down(urlStr: url, savePath: path!, result: result, app21: app21, returnType: returnType);
            break;
        case 1:
            //cached if not get
            if( fileManage.fileExists(atPath: getAbsPath(relPath: path)!.path))
            {
                response(file: path!, returnType: returnType, result: result, app21: app21)
            }else{
                down(urlStr: url, savePath: path!, result: result, app21: app21, returnType: returnType);
            }
            break;
        case 2:
            //only get
            down(urlStr: url, savePath: path!, result: result, app21: app21, returnType: returnType);
            break;
        case 3:
            //only cached
            if( fileManage.fileExists(atPath: getAbsPath(relPath: path)!.path))
            {
                response(file: path!, returnType: returnType, result: result, app21: app21)
            }else{
                result.data = JSON("FILE_NOT_FOUND");
                result.success = false;
                app21.App21Result(result: result);
            }
            break;
        case 4:
            //delete cached
            if( fileManage.fileExists(atPath: path!))
            {
                do{
                  try!  fileManage.removeItem(atPath: path!)
                }catch{
                    
                }
            }else{
                result.data = JSON("FILE_NOT_FOUND");
                result.success = false;
                app21.App21Result(result: result);
            }
            break;
        default:
            result.data = JSON("KHONG_HO_TRO_" + type.description);
            result.success = false;
            app21.App21Result(result: result);
            break;
        }
    }
}

class EZDownloader {
     func load(URL: URL?) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        var request = URLRequest(url: URL!)
        request.httpMethod = "GET";
        
        
        
         let task = session.dataTask(with: request, completionHandler:{ (data: Data?,rsp: URLResponse?, error: Error? ) -> Void in
             //
             let x = data;
             
         }
         )
        
    }
}

class DownUrlResult
{
    var path: String? = nil;
    var absPath: URL? = nil;
}
