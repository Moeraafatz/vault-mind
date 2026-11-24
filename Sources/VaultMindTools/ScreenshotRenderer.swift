import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import VaultMindUI

@MainActor
enum VaultScreenshotRenderer {
    static func renderAll(outputDir: URL) throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let askImg = try renderCard(tab: .ask)
        let compareImg = try renderCard(tab: .compare)
        let foldersImg = try renderCard(tab: .folders)
        let privacyImg = try renderCard(tab: .privacy)

        try VaultIconGenerator.writePNG(askImg, to: outputDir.appendingPathComponent("ask.png"))
        try VaultIconGenerator.writePNG(compareImg, to: outputDir.appendingPathComponent("compare.png"))
        try VaultIconGenerator.writePNG(foldersImg, to: outputDir.appendingPathComponent("folders.png"))
        try VaultIconGenerator.writePNG(privacyImg, to: outputDir.appendingPathComponent("privacy.png"))

        let hero = try renderHeroBanner(ask: askImg, compare: compareImg, folders: foldersImg)
        try VaultIconGenerator.writePNG(hero, to: outputDir.appendingPathComponent("hero.png"))
    }

    private static func renderCard(tab: VaultTab) throws -> CGImage {
        let state = VaultAppState.demo(tab: tab)
        let framed = RootVaultView(state: state, width: 510)
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.028, green: 0.032, blue: 0.062),
                        Color(red: 0.012, green: 0.015, blue: 0.032)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2.0
        guard let cg = renderer.cgImage else {
            throw NSError(domain: "VaultMindTools.Screenshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "ImageRenderer returned nil for \(tab.rawValue)"])
        }
        return cg
    }

    private static func renderHeroBanner(ask: CGImage, compare: CGImage, folders: CGImage) throws -> CGImage {
        let heroView = ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.028, blue: 0.056),
                    Color(red: 0.012, green: 0.014, blue: 0.028)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [VaultTheme.indigo.opacity(0.24), Color.clear],
                center: UnitPoint(x: 0.22, y: 0.20),
                startRadius: 20,
                endRadius: 560
            )
            RadialGradient(
                colors: [VaultTheme.mint.opacity(0.18), Color.clear],
                center: UnitPoint(x: 0.80, y: 0.80),
                startRadius: 20,
                endRadius: 560
            )

            VStack(spacing: 26) {
                HStack(spacing: 12) {
                    Text("VAULT MIND")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(VaultTheme.mint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(VaultTheme.indigo.opacity(0.22))
                                .overlay(Capsule().strokeBorder(VaultTheme.mint.opacity(0.45), lineWidth: 1))
                        )
                    Text("Cited Local RAG · Auto Cross-File Comparison Matrices · Live FSEvents Indexer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VaultTheme.textSecondary)
                }

                HStack(alignment: .center, spacing: 24) {
                    panelPreview(image: ask, caption: "Cited Local Analyst (⌘1)")
                    panelPreview(image: compare, caption: "Cross-File Comparison Matrix (⌘2)")
                    panelPreview(image: folders, caption: "Live FSEvents Folder Vault (⌘3)")
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 34)
        }
        .frame(width: 1640, height: 880)
        .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: heroView)
        renderer.scale = 2.0
        guard let cg = renderer.cgImage else {
            throw NSError(domain: "VaultMindTools.Screenshot", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to render hero banner"])
        }
        return cg
    }

    private static func panelPreview(image: CGImage, caption: String) -> some View {
        VStack(spacing: 10) {
            Image(decorative: image, scale: 2.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 495)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 14)

            Text(caption)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(VaultTheme.textSecondary)
        }
    }
}
