//
//  LauncherChrome.swift
//  Saci
//

import SwiftUI
import AppKit

// @note shared design tokens for Sequoia-era chrome vs macOS 26+ Liquid Glass
enum LauncherChrome {
    // @note true when running on macOS 26+ where Liquid Glass APIs are available
    static var usesLiquidGlass: Bool {
        if #available(macOS 26, *) {
            return true
        }
        return false
    }
    
    static var panelCornerRadius: CGFloat {
        usesLiquidGlass ? 30 : 12
    }
    
    static var chipCornerRadius: CGFloat {
        usesLiquidGlass ? 12 : 6
    }
    
    static var rowCornerRadius: CGFloat {
        usesLiquidGlass ? 10 : 6
    }
    
    static var cardCornerRadius: CGFloat {
        usesLiquidGlass ? 14 : 10
    }
    
    static var menuCornerRadius: CGFloat {
        usesLiquidGlass ? 16 : 12
    }
    
    static var badgeCornerRadius: CGFloat {
        usesLiquidGlass ? 6 : 4
    }
    
    // @note footer top padding
    static var footerTopPadding: CGFloat { 8 }
    
    // @note extra bottom inset so footer content clears the rounded panel edge
    static var footerBottomPadding: CGFloat {
        usesLiquidGlass ? 12 : 8
    }
    
    static var panelShadowRadius: CGFloat {
        usesLiquidGlass ? 8 : 20
    }
    
    static var panelShadowY: CGFloat {
        usesLiquidGlass ? 4 : 10
    }
    
    static var panelShadowOpacity: Double {
        usesLiquidGlass ? 0.12 : 0.3
    }
    
    static var menuShadowOpacity: Double {
        usesLiquidGlass ? 0.15 : 0.25
    }
}

// @note dual-path panel/settings background (Liquid Glass on macOS 26+, VisualEffect elsewhere)
struct LauncherBackground: View {
    var enableTransparency: Bool
    var cornerRadius: CGFloat
    var solidColor: Color
    var overlayColor: Color
    var material: NSVisualEffectView.Material = .hudWindow
    
    @ViewBuilder
    var body: some View {
        if enableTransparency {
            if #available(macOS 26, *) {
                liquidGlassBackground
            } else {
                legacyBlurBackground
            }
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(solidColor)
        }
    }
    
    // @note Liquid Glass surface for macOS 26+
    @available(macOS 26, *)
    private var liquidGlassBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.clear)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    // @note Sequoia-era hud blur + tint overlay
    private var legacyBlurBackground: some View {
        ZStack {
            VisualEffectBackground(
                material: material,
                blendingMode: .behindWindow,
                cornerRadius: cornerRadius,
                opacity: 1.0
            )
            
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(overlayColor)
        }
    }
}

// @note full-bleed settings window background (no clipped corner mask)
struct SettingsWindowBackground: View {
    var enableTransparency: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private var solidColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.12, alpha: 1))
            : Color(nsColor: NSColor.windowBackgroundColor)
    }
    
    @ViewBuilder
    var body: some View {
        if enableTransparency {
            if #available(macOS 26, *) {
                Color.clear
                    .glassEffect(.regular)
                    .ignoresSafeArea()
            } else {
                VisualEffectBackground(
                    material: .sidebar,
                    blendingMode: .behindWindow,
                    cornerRadius: 0,
                    opacity: 1.0
                )
                .ignoresSafeArea()
            }
        } else {
            solidColor.ignoresSafeArea()
        }
    }
}

// @note floating chip / filter control chrome (glass on macOS 26+, flat fill elsewhere)
struct FloatingChipBackground: ViewModifier {
    var cornerRadius: CGFloat
    var fillColor: Color
    var strokeColor: Color
    var enableGlass: Bool = true
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), enableGlass, LauncherChrome.usesLiquidGlass {
            content
                .background(
                    Capsule()
                        .fill(Color.clear)
                        .glassEffect(.regular.interactive(), in: Capsule())
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
        }
    }
}

extension View {
    // @note apply floating chip chrome with Liquid Glass fallback
    // @param cornerRadius legacy corner radius
    // @param fillColor legacy fill
    // @param strokeColor legacy stroke
    // @param enableGlass whether to use glass when available
    func floatingChipChrome(
        cornerRadius: CGFloat = LauncherChrome.chipCornerRadius,
        fillColor: Color = Color.secondary.opacity(0.12),
        strokeColor: Color = Color.secondary.opacity(0.3),
        enableGlass: Bool = true
    ) -> some View {
        modifier(FloatingChipBackground(
            cornerRadius: cornerRadius,
            fillColor: fillColor,
            strokeColor: strokeColor,
            enableGlass: enableGlass
        ))
    }
    
    // @note glass treatment for floating menus/popovers on macOS 26+
    // @param cornerRadius corner radius for both paths
    // @param fillColor legacy solid fill
    // @param strokeColor legacy border
    // @param shadowOpacity drop shadow strength
    @ViewBuilder
    func floatingMenuChrome(
        cornerRadius: CGFloat = LauncherChrome.menuCornerRadius,
        fillColor: Color,
        strokeColor: Color,
        shadowOpacity: Double = LauncherChrome.menuShadowOpacity
    ) -> some View {
        if #available(macOS 26, *), LauncherChrome.usesLiquidGlass {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                )
                .shadow(color: .black.opacity(shadowOpacity), radius: 12, x: 0, y: 4)
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
                .shadow(color: .black.opacity(shadowOpacity), radius: 16, x: 0, y: 6)
        }
    }
    
    // @note soften card fills on Liquid Glass; keep legacy cards elsewhere
    // @param cornerRadius card corner radius
    // @param fillColor legacy card fill
    // @param selected whether card is selected
    @ViewBuilder
    func launcherCardChrome(
        cornerRadius: CGFloat = LauncherChrome.cardCornerRadius,
        fillColor: Color,
        selected: Bool
    ) -> some View {
        if #available(macOS 26, *), LauncherChrome.usesLiquidGlass {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.secondary.opacity(selected ? 0.18 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            selected ? Color.accentColor.opacity(0.45) : Color.clear,
                            lineWidth: 1.5
                        )
                )
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            selected ? Color.accentColor.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
        }
    }
}
