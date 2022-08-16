//
//  Configuration.swift
//  
//
//  Created by 张行 on 2022/5/17.
//

import Foundation

class Configuration {
    let pwd: String
    let home: String
    let zealotToken: String
    let zealotChannelKey: String
    let zealotHost: String
    
    init(uploadZealot:Bool) throws {
        guard let pwd = ProcessInfo.processInfo.environment["PWD"] else {
            throw "$PWD为空"
        }
        self.pwd = pwd
        guard let home = ProcessInfo.processInfo.environment["HOME"] else {
            throw "$HOME为空"
        }
        self.home = home
        if (uploadZealot) {
            guard let zealotToken = ProcessInfo.processInfo.environment["ZEALOT_TOKEN"] else {
                throw "ZEALOT_TOKEN不存在"
            }
            self.zealotToken = zealotToken
            guard let channelKey = ProcessInfo.processInfo.environment["ZEALOT_CHANNEL_KEY"] else {
                throw "ZEALOT_CHANNEL_KEY不存在"
            }
            self.zealotChannelKey = channelKey
            guard let uploadHost = ProcessInfo.processInfo.environment["ZEALOT_HOST"] else {
                throw "ZEALOT_HOST 不存在"
            }
            self.zealotHost = uploadHost
        } else {
            self.zealotHost = ""
            self.zealotToken = ""
            self.zealotChannelKey = ""
        }
    }
}
