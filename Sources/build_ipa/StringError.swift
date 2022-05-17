//
//  StringError.swift
//  
//
//  Created by 张行 on 2021/11/1.
//

import Foundation

extension String: LocalizedError {
    public var errorDescription: String? {self}
}
