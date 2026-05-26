//
//  CurrentDeviceInfoCard.swift
//  simdock
//

import SwiftUI

struct CurrentDeviceInfoCard: View {
    var device: SimulatedDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: device.symbolName)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .simDockGlass(cornerRadius: 17)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        LiveDot()
                        Text("\(device.connectionSummary) · \(device.statusText)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                DeviceInfoPill(title: "Runtime", value: device.osVersion)
                DeviceInfoPill(title: "Latency", value: device.latencyText)
            }

            HStack(spacing: 8) {
                DeviceInfoPill(title: "Stream", value: device.frameRateText)
                DeviceInfoPill(title: "Host", value: device.hostText)
            }

            Text(device.identifierText)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.46), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}
