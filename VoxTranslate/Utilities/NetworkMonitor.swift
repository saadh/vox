// NetworkMonitor.swift
// VoxTranslate
//
// NWPathMonitor wrapper for connectivity detection and tier switching.

import Foundation
import Network
import os.log

// MARK: - Network Monitor

/// Monitors network connectivity using `NWPathMonitor` to drive engine tier switching.
///
/// When connectivity changes, the `EngineManager` is notified so it can automatically
/// promote or demote the active translation engine tier.
@Observable
final class NetworkMonitor: @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "Network")
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.voxtranslate.network", qos: .utility)

    /// Whether the device currently has network connectivity.
    private(set) var isConnected = true

    /// The current connection type.
    private(set) var connectionType: ConnectionType = .unknown

    /// Callback invoked when connectivity changes.
    var onConnectivityChanged: ((Bool) -> Void)?

    // MARK: - Connection Type

    enum ConnectionType: Sendable {
        case wifi
        case cellular
        case wired
        case unknown
    }

    // MARK: - Initialization

    init() {}

    deinit {
        stop()
    }

    // MARK: - Monitoring

    /// Starts monitoring network connectivity.
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let wasConnected = self.isConnected
            self.isConnected = path.status == .satisfied

            self.connectionType = self.determineConnectionType(path)

            if wasConnected != self.isConnected {
                self.logger.info("Network connectivity changed: \(self.isConnected ? "connected" : "disconnected") via \(String(describing: self.connectionType))")
                self.onConnectivityChanged?(self.isConnected)
            }
        }

        monitor.start(queue: monitorQueue)
        logger.info("Network monitoring started")
    }

    /// Stops monitoring network connectivity.
    func stop() {
        monitor.cancel()
        logger.info("Network monitoring stopped")
    }

    // MARK: - Connection Type Detection

    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        } else {
            return .unknown
        }
    }
}
