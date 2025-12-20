//
//  XPZ.swift
//  ezsspa
//
//  Created by Admin on 21/10/2024.
//  Copyright © 2024 High Sierra. All rights reserved.
//

import Foundation
import Network
import UIKit
import CoreFoundation

class XPZ: NSObject
{
    var app21: App21? = nil;
    var result: Result? = nil;
    
    private var inited: Bool = false;
    private var connectStatus: Int = 0;
    private var ipConnected: String? = nil;
    private var port: Int? = nil;
    private var _ipAddress: String? = nil;
    
    private var width: Int = 320;
    private var printParam: XPZParam? = nil;
    
    private var resource: [URL?] = [];
    
    private var tcpPrinter: TCPPrinterConnection? = nil;
    
    
    
    
    @objc func reset()-> Void
    {
        tcpPrinter?.disconnect()
        tcpPrinter = nil
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
        if connectStatus != 0 {
            return
        }
        connectStatus = 1
        
        if tcpPrinter == nil {
            tcpPrinter = TCPPrinterConnection()
        }
        
        tcpPrinter?.connect(host: ipAddress, port: UInt16(port)) { [weak self] (result: Swift.Result<Void, Error>) in
            guard let self = self else { return }
            switch result {
            case .success:
                self.onConected(ip: ipAddress, port: port)
            case .failure(let error):
                self.onError(err: error.localizedDescription)
            }
        }
        
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
        
        let paperWidth = Int(printParam?.paperWidth ?? 0)
        let builder = ESCPosBuilder(paperWidth: paperWidth)
        
        do {
            try builder.appendItems(printParam?.items ?? [], resourceCollector: &resource)
            
            if printParam?.feedLine == true {
                builder.appendFeedLine()
            }
            
            let trailingFeed = printParam?.cutHalfAndFeed ?? 0
            let shouldCut = printParam?.cutPaper ?? false
            let printData = builder.data
            self.printParam = nil
            
            tcpPrinter?.send(printData) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.result?.success = false
                    self.result?.data = JSON(error.localizedDescription)
                    self.app21?.App21Result(result: self.result!)
                    return
                }
                
                let tailData = ESCPosBuilder.trailingCommands(feedLines: trailingFeed, cut: shouldCut)
                if tailData.isEmpty {
                    self.result?.success = true
                    self.result?.data = JSON("done")
                    self.app21?.App21Result(result: self.result!)
                    return
                }
                
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    self.tcpPrinter?.send(tailData) { tailError in
                        if let tailError = tailError {
                            self.result?.success = false
                            self.result?.data = JSON(tailError.localizedDescription)
                        } else {
                            self.result?.success = true
                            self.result?.data = JSON("done")
                        }
                        self.app21?.App21Result(result: self.result!)
                    }
                }
            }
        } catch {
            result?.success = false
            result?.data = JSON("image fail:" + error.localizedDescription)
            app21?.App21Result(result: result!)
        }
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
    var paperWidth: Int? = 0;
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

final class TCPPrinterConnection {
    private let queue = DispatchQueue(label: "xpz.printer.tcp")
    private var connection: NWConnection?
    private var targetHost: String?
    private var targetPort: UInt16?
    
    func connect(host: String, port: UInt16, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        targetHost = host
        targetPort = port
        var didComplete = false
        
        let endpointHost = NWEndpoint.Host(host)
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            completion(.failure(NSError(domain: "TCPPrinter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid port"])))
            return
        }
        
        let connection = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)
        self.connection = connection
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if !didComplete {
                    didComplete = true
                    completion(.success(()))
                }
            case .failed(let error):
                if !didComplete {
                    didComplete = true
                    completion(.failure(error))
                }
            case .cancelled:
                if !didComplete {
                    didComplete = true
                    completion(.failure(NSError(domain: "TCPPrinter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Connection cancelled"])))
                }
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    func send(_ data: Data, completion: @escaping (Error?) -> Void) {
        guard let connection = connection else {
            completion(NSError(domain: "TCPPrinter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Not connected"]))
            return
        }
        let chunkSize = 2048
        var offset = 0
        
        func sendNext() {
            if offset >= data.count {
                completion(nil)
                return
            }
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)
            connection.send(content: chunk, completion: .contentProcessed { error in
                if let error = error {
                    completion(error)
                    return
                }
                offset = end
                if data.count > chunkSize {
                    self.queue.asyncAfter(deadline: .now() + 0.01) {
                        sendNext()
                    }
                } else {
                    sendNext()
                }
            })
        }
        
        sendNext()
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
    }
}

final class ESCPosBuilder {
    private(set) var data = Data()
    private let paperWidth: Int
    
    init(paperWidth: Int) {
        self.paperWidth = paperWidth
        appendInitialize()
    }
    
    func appendItems(_ items: [XPZItem], resourceCollector: inout [URL?]) throws {
        for item in items {
            if let url = item.imageLocalPath {
                let fileData = try Data(contentsOf: url)
                resourceCollector.append(url)
                guard let image = UIImage(data: fileData) else {
                    throw NSError(domain: "ESCPosBuilder", code: -10, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                }
                appendImage(image, alignment: Int(item.alignment ?? 0), targetWidth: Int(item.width ?? 0))
            }
            
            if let text = item.text {
                appendText(text, alignment: Int(item.alignment ?? 0))
            }
            
            if let base64 = item.base64 {
                let raw = base64.replacingOccurrences(of: "data:image/png;base64,", with: "")
                guard let imageData = Data(base64Encoded: raw, options: .ignoreUnknownCharacters),
                      let image = UIImage(data: imageData) else {
                    throw NSError(domain: "ESCPosBuilder", code: -11, userInfo: [NSLocalizedDescriptionKey: "Invalid base64 image"])
                }
                appendImage(image, alignment: Int(item.alignment ?? 0), targetWidth: Int(item.width ?? 0))
            }
        }
    }
    
    func appendText(_ text: String, alignment: Int) {
        data.append(contentsOf: [0x1B, 0x61, UInt8(clampAlignment(alignment))])
        data.append(contentsOf: [0x1B, 0x2D, 0x01])
        data.append(contentsOf: [0x1B, 0x45, 0x01])
        let cfEncoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        if let encoded = text.data(using: encoding) {
            data.append(encoded)
        }
    }
    
    func appendFeedLine() {
        data.append(0x0A)
    }
    
    func appendFeedLines(_ lines: Int) {
        let n = UInt8(max(0, min(lines, 255)))
        data.append(contentsOf: [0x1B, 0x64, n])
    }
    
    func appendCut() {
        data.append(contentsOf: [0x1D, 0x56, 0x00])
    }

    static func trailingCommands(feedLines: Int, cut: Bool) -> Data {
        var tail = Data()
        let n = UInt8(max(0, min(feedLines, 255)))
        if n > 0 {
            tail.append(contentsOf: [0x1B, 0x64, n])
        }
        if cut {
            tail.append(contentsOf: [0x1D, 0x56, 0x00])
        }
        return tail
    }
    
    private func appendInitialize() {
        data.append(contentsOf: [0x1B, 0x40])
    }
    
    private func appendImage(_ image: UIImage, alignment: Int, targetWidth: Int) {
        data.append(contentsOf: [0x1B, 0x61, UInt8(clampAlignment(alignment))])
        
        let maxWidth = effectivePaperWidth()
        let desiredWidth = targetWidth > 0 ? min(targetWidth, maxWidth) : maxWidth
        let scaled = scaleImage(image, targetWidth: desiredWidth)
        let raster = rasterizeImageBands(scaled, bandHeight: 24)
        data.append(raster)
        data.append(0x0A)
    }
    
    private func clampAlignment(_ value: Int) -> Int {
        if value < 0 { return 0 }
        if value > 2 { return 2 }
        return value
    }
    
    private func effectivePaperWidth() -> Int {
        if paperWidth > 0 {
            return paperWidth
        }
        return 576
    }
    
    private func scaleImage(_ image: UIImage, targetWidth: Int) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let width = cgImage.width
        let height = cgImage.height
        if width <= targetWidth || targetWidth <= 0 {
            return image
        }
        let scale = CGFloat(targetWidth) / CGFloat(width)
        let targetHeight = Int(CGFloat(height) * scale)
        let newSize = CGSize(width: targetWidth, height: targetHeight)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaled ?? image
    }
    
    private func rasterizeImageBands(_ image: UIImage, bandHeight: Int) -> Data {
        guard let cgImage = image.cgImage else { return Data() }
        let width = cgImage.width
        let height = cgImage.height
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bytesPerRow = width
        var pixels = [UInt8](repeating: 0, count: width * height)
        
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return Data()
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let bytesPerRowBits = (width + 7) / 8
        var bitmap = [UInt8](repeating: 0, count: bytesPerRowBits * height)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixel = pixels[y * width + x]
                if pixel < 128 {
                    let index = y * bytesPerRowBits + (x / 8)
                    bitmap[index] |= (0x80 >> (x % 8))
                }
            }
        }
        
        var output = Data()
        let xL = UInt8(bytesPerRowBits & 0xFF)
        let xH = UInt8((bytesPerRowBits >> 8) & 0xFF)
        let step = max(1, bandHeight)
        
        var y = 0
        while y < height {
            let bandRows = min(step, height - y)
            let yL = UInt8(bandRows & 0xFF)
            let yH = UInt8((bandRows >> 8) & 0xFF)
            output.append(contentsOf: [0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH])
            
            let start = y * bytesPerRowBits
            let end = start + bandRows * bytesPerRowBits
            output.append(contentsOf: bitmap[start..<end])
            y += bandRows
        }
        
        return output
    }
}
