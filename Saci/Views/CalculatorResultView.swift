//
//  CalculatorResultView.swift
//  Saci
//

import SwiftUI

// @note calculator result row with centered equation layout
struct CalculatorResultView: View {
    let result: CalculatorResult
    let isSelected: Bool
    var showCopied: Bool = false
    let onCopy: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    // @note selection background color based on theme
    private var selectionColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.85, alpha: 1))
    }
    
    // @note inner container background color (70% opacity)
    private var containerColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.15, alpha: 0.7))
            : Color(nsColor: NSColor(white: 0.95, alpha: 0.7))
    }
    
    // @note truncate expression if too long
    private var displayExpression: String {
        let maxLength = 25
        if result.expression.count > maxLength {
            let half = (maxLength - 3) / 2
            let start = result.expression.prefix(half)
            let end = result.expression.suffix(half)
            return "\(start)...\(end)"
        }
        return result.expression
    }
    
    // @note calculation type label text
    private var typeLabel: String {
        switch result.type {
        case .number:
            return "Basic Arithmetic"
        case .percentage:
            return "Percentage"
        case .date:
            return "Date Calculation"
        case .time:
            return "Time Zone"
        case .unit:
            return "Unit Conversion"
        case .power:
            return "Power / Exponent"
        case .squareRoot:
            return "Square Root"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // @note main equation display: expression = result
            HStack(spacing: 12) {
                // @note expression (left side)
                Text(displayExpression)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // @note equals sign
                Text("=")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                // @note result (right side)
                Text(result.result)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // @note copy indicator or hint
                if showCopied {
                    CopiedBadge()
                } else if isSelected {
                    CopyHintBadge()
                }
            }
            
            // @note calculation type label
            Text(typeLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(containerColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.5) : Color.clear,
                    lineWidth: 2
                )
        )
    }
}

// @note copied badge component
private struct CopiedBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text("Copied")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.green.opacity(0.15))
        )
    }
}

// @note copy hint badge component
private struct CopyHintBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("⏎")
                .font(.system(size: 11, weight: .medium))
            Text("Copy")
                .font(.system(size: 11))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.15))
        )
    }
}

// @note calculator section header
struct CalculatorSectionHeader: View {
    @Environment(\.colorScheme) var colorScheme
    
    private var headerColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.4, alpha: 1))
            : Color(nsColor: NSColor(white: 0.5, alpha: 1))
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "function")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text("Calculator")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .foregroundColor(headerColor)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// @note container for calculator result with header
struct CalculatorResultContainer: View {
    let result: CalculatorResult
    let isSelected: Bool
    var showCopied: Bool = false
    let onCopy: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            CalculatorSectionHeader()
            
            CalculatorResultView(
                result: result,
                isSelected: isSelected,
                showCopied: showCopied,
                onCopy: onCopy
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CalculatorResultContainer(
            result: CalculatorResult(
                type: .number,
                expression: "20*9123014123",
                result: "182,460,282,460",
                subtitle: "Basic arithmetic",
                icon: "equal.circle.fill"
            ),
            isSelected: true,
            showCopied: false,
            onCopy: {}
        )
        
        CalculatorResultContainer(
            result: CalculatorResult(
                type: .percentage,
                expression: "15% of 200",
                result: "30",
                subtitle: "15% of 200",
                icon: "percent"
            ),
            isSelected: false,
            showCopied: false,
            onCopy: {}
        )
        
        CalculatorResultContainer(
            result: CalculatorResult(
                type: .unit,
                expression: "100C to F",
                result: "212 °F",
                subtitle: "100 °C = 212 °F",
                icon: "thermometer.medium"
            ),
            isSelected: false,
            showCopied: false,
            onCopy: {}
        )
        
        CalculatorResultContainer(
            result: CalculatorResult(
                type: .time,
                expression: "5pm jkt in nyc",
                result: "5:00 AM",
                subtitle: "5:00 PM JKT → NYC",
                icon: "clock.fill"
            ),
            isSelected: false,
            showCopied: false,
            onCopy: {}
        )
        
        // @note test long expression truncation
        CalculatorResultContainer(
            result: CalculatorResult(
                type: .number,
                expression: "123456789012345678901234567890",
                result: "1.23456789E29",
                subtitle: "Basic arithmetic",
                icon: "equal.circle.fill"
            ),
            isSelected: false,
            showCopied: true,
            onCopy: {}
        )
    }
    .frame(width: 680)
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}
