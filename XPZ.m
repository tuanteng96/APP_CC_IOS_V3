//
//  XPZ.m
//  ezsspa
//
//  Created by Admin on 25/10/2024.
//  Copyright © 2024 High Sierra. All rights reserved.
//

#import "XPZ.h"
#import "PrinterSDK/Headers/POSPrinterSDK.h"
#import "PrinterSDK/Headers/PTable.h"

typedef NS_ENUM(NSInteger, ConnectType) {
    NONE = 0,   //None
    BT,         //Bluetooth
    WIFI,       //WiFi
};
@implementation ObjcPrint
POSWIFIManager *wifiManager;
ConnectType connectType = WIFI;


- (void) printText: (NSString*) text alignment:(int) alignment attribute:(int) attribute textSize:(int) textSize
{
    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    NSStringEncoding gbkEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    [dataM appendData:[POSCommand selectOrCancleUnderLineModel:1]];//下划线
    [dataM appendData:[POSCommand selectOrCancleBoldModel:1]];//加粗
    [dataM appendData:[POSCommand selectAlignment:alignment]];//居中对齐
    [dataM appendData: [text dataUsingEncoding: gbkEncoding]];
    
    [self printWithData:dataM];
}

- (void) printImage: (UIImage*) img alignment:(int) alignment{
    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    [dataM appendData:[POSCommand selectAlignment:alignment]];
    [dataM appendData:[POSCommand printRasteBmpWithM:RasterNolmorWH andImage:img andType:Dithering]];
    [self printWithData:dataM];

}

- (void) feedLine {
    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    [dataM appendData:[POSCommand printAndFeedLine]];
    [self printWithData:dataM];
    
}

- (void) cutHalfAndFeed: (int) cutHalfAndFeed{
    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    [dataM appendData:[POSCommand printAndFeedForwardWhitN: cutHalfAndFeed]];
    [self printWithData:dataM];
}

- (void) cutPaper{
    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    [dataM appendData:[POSCommand selectCutPageModelAndCutpage:1]];
    [self printWithData:dataM];
}

- (void)printWithData:(NSData *)printData {
    switch (connectType) {
        case NONE:
            
            break;
            
        case WIFI:
            [_wifiManager writeCommandWithData:printData];
            break;
            
        case BT:
            
            break;
            
        default:
            break;
    }
}

@end
