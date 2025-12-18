//
//  LocalScheme.swift
//  Cser21
//
//  Created by Hung-Catalina on 3/22/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//

import Foundation
import WebKit


@available(iOS 11.0, *)
class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
   

    enum CustomSchemeHandlerError: Error {
        case noIdeaWhatToDoWithThis
        case fileNotFound(fileName: String)
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        
       // var url = urlSchemeTask.request.url?.absoluteString
       // var file = DownloadFileTask.urlToLocalFileName(url!);
        
        // Make sure the task is for a dr-bundle-file
        guard let url = urlSchemeTask.request.url,
            let scheme = url.scheme,
            scheme == "local" ||
            scheme == "js" ||
            scheme == "app21" else {
                urlSchemeTask.didFailWithError(CustomSchemeHandlerError.noIdeaWhatToDoWithThis)
                return
        }
        
        // Extract the required file name from the request.
        let urlString = String( url.absoluteString.split(separator: "?").first!)
        
        let index = urlString.index(urlString.startIndex, offsetBy: "local://".count)
        let file = String(urlString[index..<urlString.endIndex])
        //let path = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        
        // Try and find the file in the app bundle.
        
        
        // Load the data from the file and prepare a URLResponse.
        let data =  DownloadFileTask.readData2(filePath: file);
        if(data != nil){
            
            if(data!.count == 0)
            {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: file) {
                   
                } else {
                    urlSchemeTask.didFailWithError(Error21.runtimeError("404"))
                    return;
                }
            }
            let response = URLResponse(url: url,
                                       mimeType: mime(ext: "." + ext),
                                       expectedContentLength: data!.count,
                                       textEncodingName: nil)
            
            // Fulfill the task.
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data!)
            urlSchemeTask.didFinish()
        }
        else{
            
            urlSchemeTask.didFailWithError(Error21.runtimeError("500"))
        }
       
       
    }
    
    func mime(ext: String) -> String {
        
        let map = [
            ".aac":"audio/aac",".abw":"application/x-abiword",".arc":"application/x-freearc",".avi":"video/x-msvideo",".azw":"application/vnd.amazon.ebook",".bin":"application/octet-stream",".bmp":"image/bmp",".bz":"application/x-bzip",".bz2":"application/x-bzip2",".csh":"application/x-csh",".css":"text/css",".csv":"text/csv",".doc":"application/msword",".docx":"application/vnd.openxmlformats-officedocument.wordprocessingml.document",".eot":"application/vnd.ms-fontobject",".epub":"application/epub+zip",".gz":"application/gzip",".gif":"image/gif",".htm .html":"text/html",".ico":"image/vnd.microsoft.icon",".ics":"text/calendar",".jar":"application/java-archive",".jpeg":".jpg",".js":"text/javascript",".json":"application/json",".jsonld":"application/ld+json",".mid":".midi",".mjs":"text/javascript",".mp3":"audio/mpeg",".mpeg":"video/mpeg",".mpkg":"application/vnd.apple.installer+xml",".odp":"application/vnd.oasis.opendocument.presentation",".ods":"application/vnd.oasis.opendocument.spreadsheet",".odt":"application/vnd.oasis.opendocument.text",".oga":"audio/ogg",".ogv":"video/ogg",".ogx":"application/ogg",".opus":"audio/opus",".otf":"font/otf",".png":"image/png",".pdf":"application/pdf",".php":"application/php",".ppt":"application/vnd.ms-powerpoint",".pptx":"application/vnd.openxmlformats-officedocument.presentationml.presentation",".rar":"application/vnd.rar",".rtf":"application/rtf",".sh":"application/x-sh",".svg":"image/svg+xml",".swf":"application/x-shockwave-flash",".tar":"application/x-tar",".tif .tiff":"image/tiff",".ts":"video/mp2t",".ttf":"font/ttf",".txt":"text/plain",".vsd":"application/vnd.visio",".wav":"audio/wav",".weba":"audio/webm",".webm":"video/webm",".webp":"image/webp",".woff":"font/woff",".woff2":"font/woff2",".xhtml":"application/xhtml+xml",".xls":"application/vnd.ms-excel",".xlsx":"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",".xml":"XML",".xul":"application/vnd.mozilla.xul+xml",".zip":"application/zip",".3gp":"video/3gpp",".3g2":"video/3gpp2",".7z":"application/x-7z-compressed"];
        
        
        return map[ext.lowercased()] ?? ""
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        //
    }
    
    
}

