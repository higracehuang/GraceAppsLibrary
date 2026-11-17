//
//  UXTriggerCatalog.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/17/26.
//

import Foundation

/// Protocol defining the strongly-typed trigger catalog for an application's
/// monetization, review, and presentation orchestration flows.
public protocol UXTriggerCatalog {
    associatedtype AdTrigger: RawRepresentable, CaseIterable, Sendable where AdTrigger.RawValue == String
    associatedtype PaywallTrigger: RawRepresentable, CaseIterable, Sendable where PaywallTrigger.RawValue == String
}

/// Fallback trigger enum for apps that do not define custom ad or paywall triggers.
public enum EmptyTrigger: String, CaseIterable, Sendable {
    case none = "none"
}
