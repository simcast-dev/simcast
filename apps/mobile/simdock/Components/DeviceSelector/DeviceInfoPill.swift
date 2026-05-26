//
//  DeviceInfoPill.swift
//  simdock
//

import SwiftUI

struct DeviceInfoPill: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
