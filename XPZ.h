//
//  XPZ.h
//  ezsspa
//
//  Created by Admin on 25/10/2024.
//  Copyright © 2024 High Sierra. All rights reserved.
//

#ifndef XPZ_h
#define XPZ_h

#import <Foundation/Foundation.h>
#import "PrinterSDK/Headers/POSPrinterSDK.h"
#import "PrinterSDK/Headers/PTable.h"

@interface  ObjcPrint : NSObject
@property POSWIFIManager *wifiManager;


- (void) printText:(NSString*) text alignment:(int) alignment attribute:(int) attribute textSize:(int) textSize;
- (void) feedLine;
- (void) cutHalfAndFeed: (int) cutHalfAndFeed;
- (void) cutPaper;
- (void) printImage: (UIImage*) img alignment:(int) alignment;
@end

#endif /* XPZ_h */
