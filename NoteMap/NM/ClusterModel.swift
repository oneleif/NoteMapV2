//
//  ClusterModel.swift
//  NoteMap
//
//  Created by Zach Eriksen on 5/14/18.
//  Copyright © 2018 oneleif. All rights reserved.
//

import Foundation

struct ClusterModel: Codable {
    var notes: [NoteModel]
    var title: String
}
