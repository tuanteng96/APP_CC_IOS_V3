//
//  XPZ.swift
//  ezsspa
//
//  Created by Admin on 21/10/2024.
//  Copyright © 2024 High Sierra. All rights reserved.
//

import Foundation

class XPZ: NSObject
{
    var app21: App21? = nil;
    var result: Result? = nil;
    //private var printer: POSPrinter? = null
    //private var curConnect: IDeviceConnection? = null
    
    private var inited: Bool = false;
    private var connectStatus: Int = 0;
    private var ipConnected: String? = nil;
    private var port: Int? = nil;
    private var _ipAddress: String? = nil;
    
    private var width: Int = 320;
    //private var printBmp: Bitmap? = nil;
    //private var printText: String? = nil;
    private var printParam: XPZParam? = nil;
    
    private var resource: [URL?] = [];
    
    var objp: ObjcPrint? = nil;
    
    
    
    
    @objc func reset()-> Void
    {
        //printer = nil;
        //curConnect = nil;
        connectStatus = 0;
        ipConnected = nil;
        printParam = nil;
    }
    @objc func response(success: Bool, dataText: String?) -> Void
    {
        result?.success = success;
        result?.data = JSON(rawValue: dataText!);
        app21?.App21Result(result: result!);
        
    }
    @objc func onConected(ip: String, port: Int) -> Void
    {
        connectStatus = 200;
        self.ipConnected = ip;
        self.port = port;
        doPrint();
    }
    @objc func onError(err: String) -> Void
    {
        reset();
        result?.data = JSON(err);
        result?.success = false;
        app21?.App21Result(result: result!);
    }
    @objc func connectNet(ipAddress: String, port: Int) throws -> Void
    
    {
        if(objp == nil) {
            objp = ObjcPrint();
        }
        if(objp?.wifiManager == nil)
        {
            objp?.wifiManager  = POSWIFIManager();
            
            objp?.wifiManager.delegate = app21?.caller;
        }
        let _wifiManager = objp?.wifiManager;
        
        if(connectStatus != 0)
        {
            return;
        }
        connectStatus = 1;
        
        if (_wifiManager!.isConnect) {
            //[_wifiManager, disconnect];
            _wifiManager?.disconnect();
            connectStatus = 1;
        }
        
        //[_wifiManager connectWithHost:self.wifiTextField.text port:9100];
        _wifiManager?.connect(withHost: ipAddress, port: UInt16(port));
        
        //check time out
        checkTimeout()
        
        
    }
    
    func checkTimeout() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5)
        { [self] in
            if( self.connectStatus != 200)
            {
                reset();
                response(success: false, dataText: "timeout")
            }
        }
        
    }
    
    func value(_ source: Int?) -> Int32
    {
        if(source == nil)
        {
            return 0;
        }
        return Int32(source!);
    }
    @objc func doPrint() -> Void
    {
        if(printParam == nil)
        {
            result?.success = false;
            result?.data = JSON("printParam is null");
            app21?.App21Result(result: result!);
            return;
        }
        
        var br: Bool = false;
        
        printParam?.items?.forEach({ xi in
            
            if(br){
                return;
            }
            if(xi.imageLocalPath != nil)
            {
                do{
                    var url = xi.imageLocalPath;
                    var data = try Data(contentsOf: url!);
                    var img = UIImage(data: data);
                    objp?.print(img, alignment: value(xi.alignment));
                    resource.append(url);
                }
                catch{
                    br = true;
                    result?.success = false;
                    result?.data = JSON("image fail:" + error.localizedDescription);
                    app21?.App21Result(result: result!);
                }
            }
            if(xi.text != nil){
                //var  dataM = NSMutableData(data: POSCommand());
                objp?.printText(xi.text, alignment: value(xi.alignment), attribute: value(xi.attribute), textSize: value(xi.textSize))
            }
            if(xi.base64 != nil)
            {
                do
                {
                    let dataDecoded: NSData = try Data(base64Encoded: xi.base64!, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters)! as NSData;
                    
                    var img = UIImage(data: dataDecoded as Data);
                    objp?.print(img, alignment: value(xi.alignment));
                    
                }catch
                {
                    br = true;
                    result?.success = false;
                    result?.data = JSON("image fail:" + error.localizedDescription);
                    app21?.App21Result(result: result!);
                }
                
                
            }
            //xi.deleteFilesIfHas();
        })
        
        if(printParam?.feedLine == true)
        {
            objp?.feedLine()
        }
        if(printParam?.cutHalfAndFeed != nil && printParam?.cutHalfAndFeed! ?? 0  > 0)
        {
            objp?.cutHalfAndFeed(value(printParam?.cutHalfAndFeed))
        }
        if(printParam?.cutPaper == true)
        {
            objp?.cutPaper();
        }
    
        self.printParam = nil;
        if(br)
        {
            return;
        }
        result?.success = true;
        result?.data = JSON("done");
        app21?.App21Result(result: result!);
    }
    //MARK: printParam
    @objc func printParam(ipAddress: String, port: Int, param: XPZParam?) -> Void
    {
        do{
            self.printParam = param;
            if(connectStatus == 200 && ipAddress == ipConnected && self.port  == port)
            {
                 doPrint()
            }else{
                try connectNet(ipAddress: ipAddress, port: port);
                return;
                
            }
        }catch  {
            result?.success = false;
            
            result?.data = JSON( error.localizedDescription);
            app21?.App21Result(result: result!);
        }
        
    }
    
    @objc func clear()
    {
        let fm = FileManager.default
        resource.forEach({ url -> Void in
            if(url == nil)
            {
                return;
            }
            do
            {
                if fm.fileExists(atPath: url?.path ?? "")
                {
                   try fm.removeItem(atPath: url?.path ?? "")
                }
            }catch{
                
            }
        })
        resource.removeAll();
    }
}

class XPZItem: NSObject, Decodable
{
    var pdfLink: String? = nil;
    var pdfString: String? = nil;
    var cellWidth: Int? = 0;
    var cellHeightRatio: Int? = 0
    var numberOfColumns: Int? = 0
    var numberOfRows: Int? = 0
    var eclType: Int? = 0
    var eclValue: Int? = 0
    
    //text
    var text: String? = nil;
    var attribute: Int? = 0
    var textSize: Int? = 0
    
    //barcode
    var barCode: String? = nil;
    var codeType: Int? = 0
    var height: Int? = 0
    var textPosition: Int? = 0
    
    //qrcode
    var qrCode: String? = nil;
    var moduleSize: Int? = 0
    var ecLevel: Int? = 0
    
    //bitmap
    var bitmapPath: String? = nil;
    var model: Int? = 0
    
    var base64: String? = nil;
    var imageUrl: String? = nil;
    var imageLocalPath: URL? = nil;
    
    //table
    //var table: XPZTable? = nil;
    
    //pdf,text, barcode, qrCode, bitmap
    var alignment: Int? = 0
    
    //barcode, bitmap
    var width: Int? = 0
    
    @objc func deleteFilesIfHas()-> Void
    {
        if(imageLocalPath != nil)
        {
            let fm = FileManager.default;
            do{
                let x = try fm.isReadableFile(atPath: imageLocalPath?.path ?? "")
            }
            catch{
                
            }
        }
    }
}
class XPZParam: NSObject, Decodable{
    var items: [XPZItem]? = nil;
    var feedLine: Bool? = true;
    var cutHalfAndFeed: Int? = 1;
    var cutPaper: Bool? = true;
}

class XPZTable: NSObject, Decodable {
    var titles: [String]? = nil;
    var bytesPerCol: [Int]? = nil;
    var align: [Int]? = nil;
    var rows: [[String]]? = nil;
    
}
