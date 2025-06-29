//
//  pointyApp.swift
//  pointy
//
//  Created by Divakar Rajesh S on 29/06/25.
//

import SwiftUI

@main
struct pointyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
