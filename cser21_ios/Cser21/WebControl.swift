//
//  WebControl.swift
//  Cser21
//
//  Created by Hung-Catalina on 4/22/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//

import Foundation
class WebControl{
    static func toUrlWithsParams(url: String, params: [String:String]) -> String
    {
        var j = url.contains("?") ?  "&" : "?";
        var c = "";
        var s = url ;
        
        for k in params
        {
            if(j != "")
            {
                s += j;
                j = "";
            }
            s += c + k.key + "=" + k.value
            c = "&";
        }
        
        return  s;
    }
}
