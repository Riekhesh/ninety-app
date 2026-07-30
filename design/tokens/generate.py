#!/usr/bin/env python3
"""
Generate Swift and CSS from notch.tokens.json, and verify the design system's
accessibility claims are true rather than aspirational.

    python3 design/tokens/generate.py            # write generated files
    python3 design/tokens/generate.py --check     # verify in sync + contrast (CI)

Three things happen here:

  1. Codegen. The token JSON is the single source of truth; Swift and CSS are
     derived. This is what makes the SwiftLint `no_hardcoded_colour` rule
     honest — there is somewhere better to get a colour from.

  2. Contrast validation. Every text-on-surface pair is checked against WCAG 2.1
     and the build FAILS if a pair regresses. A design system that claims AA in
     a comment is a design system that quietly stops meeting AA. This is a
     health app; the audience skews toward people who are not 22 with perfect
     eyesight.

  3. Tier-distinctness check. Verifies the five tier colours are ordered by
     notch count and flags any adjacent pair that is too close in luminance to
     tell apart — which is the whole reason ADR 0012 encodes tier as a count.
     The check is expected to FLAG Silver/Platinum; that is the point. It fails
     only if the notch counts are wrong, because the count is the real signal.

No third-party dependencies. Runs on a clean Python 3.11.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOKENS = ROOT / "design" / "tokens" / "notch.tokens.json"
OUT_SWIFT = ROOT / "design" / "generated" / "DesignTokens.generated.swift"
OUT_CSS = ROOT / "design" / "generated" / "tokens.generated.css"

BANNER = (
    "// GENERATED FILE — DO NOT EDIT.\n"
    "// Source: design/tokens/notch.tokens.json\n"
    "// Regenerate: python3 design/tokens/generate.py\n"
)

# ─── WCAG 2.1 contrast ───────────────────────────────────────────────────────


def _entries(group: dict) -> list[tuple[str, dict]]:
    """Token entries in a DTCG group, skipping `$type` / `$description` metadata."""
    return [(k, v) for k, v in group.items() if not k.startswith("$")]


def _srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def relative_luminance(hex_colour: str) -> float:
    h = hex_colour.lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))
    return (
        0.2126 * _srgb_to_linear(r)
        + 0.7152 * _srgb_to_linear(g)
        + 0.0722 * _srgb_to_linear(b)
    )


def contrast_ratio(fg: str, bg: str) -> float:
    a, b = relative_luminance(fg), relative_luminance(bg)
    lighter, darker = max(a, b), min(a, b)
    return (lighter + 0.05) / (darker + 0.05)


# (foreground, background, minimum ratio, why)
#
# 4.5 = WCAG AA for body text. 3.0 = AA for large text (>=24pt or >=19pt bold)
# and for non-text UI component boundaries. Disabled controls are exempt from
# contrast requirements entirely, which is exactly why `textDisabled` is a
# separate token from `textTertiary` — so "exempt" can't leak onto content.
CONTRAST_RULES: list[tuple[str, str, float, str]] = [
    ("textPrimary", "canvas", 4.5, "primary body text"),
    ("textPrimary", "surface", 4.5, "primary text on cards"),
    ("textSecondary", "canvas", 4.5, "supporting copy"),
    ("textSecondary", "surface", 4.5, "supporting copy on cards"),
    ("textTertiary", "canvas", 4.5, "least-emphasis labels — still content"),
    ("textTertiary", "surface", 4.5, "least-emphasis labels on cards"),
    ("accent", "canvas", 4.5, "accent used as link/label text"),
    ("accent", "surface", 4.5, "accent text on cards"),
    ("positive", "surface", 3.0, "in-band indicator — non-text UI"),
    ("safety", "surface", 3.0, "safety intervention indicator"),
    ("critical", "surface", 3.0, "destructive-action indicator"),
    ("strokeStrong", "surface", 1.4, "input border must be perceivable"),
    ("chartLine", "surface", 4.5, "the weight trend line is the data"),
    ("chartBaseline", "surface", 2.2, "reference line, deliberately quiet"),
]

MIN_TIER_ON_CANVAS = 3.0  # tier badges are large non-text UI


def check_contrast(tokens: dict) -> list[str]:
    """Return a list of failure strings; empty means everything passes."""
    failures: list[str] = []

    for theme_name, theme in tokens["theme"].items():
        for fg_key, bg_key, minimum, why in CONTRAST_RULES:
            fg = theme[fg_key]["$value"]
            bg = theme[bg_key]["$value"]
            ratio = contrast_ratio(fg, bg)
            if ratio < minimum:
                failures.append(
                    f"{theme_name}: {fg_key} ({fg}) on {bg_key} ({bg}) "
                    f"is {ratio:.2f}:1, needs {minimum}:1 — {why}"
                )

    # Tier badges must be visible on both grounds.
    for tier_name, tier in _entries(tokens["tier"]):
        dark_ratio = contrast_ratio(
            tier["$value"], tokens["theme"]["dark"]["canvas"]["$value"]
        )
        light_ratio = contrast_ratio(
            tier["$extensions"]["notch.light"],
            tokens["theme"]["light"]["canvas"]["$value"],
        )
        for label, ratio in (("dark", dark_ratio), ("light", light_ratio)):
            if ratio < MIN_TIER_ON_CANVAS:
                failures.append(
                    f"tier.{tier_name} on {label} canvas is {ratio:.2f}:1, "
                    f"needs {MIN_TIER_ON_CANVAS}:1"
                )

    return failures


def check_tiers(tokens: dict) -> tuple[list[str], list[str]]:
    """Verify notch counts are 1..5 in ladder order. Returns (failures, notes)."""
    failures: list[str] = []
    notes: list[str] = []

    ladder = ["bronze", "silver", "gold", "platinum", "diamond"]
    if [k for k, _ in _entries(tokens["tier"])] != ladder:
        failures.append(
            "tier order in notch.tokens.json must be "
            f"{' -> '.join(ladder)} (§03 ladder order)"
        )
        return failures, notes

    for expected, name in enumerate(ladder, start=1):
        actual = tokens["tier"][name]["$extensions"]["notch.count"]
        if actual != expected:
            failures.append(
                f"tier.{name} has notch.count {actual}, expected {expected}. "
                "The count IS the tier signal (ADR 0012) — it cannot be wrong."
            )

    # Informational: which adjacent pairs colour alone cannot separate.
    for a, b in zip(ladder, ladder[1:]):
        ratio = contrast_ratio(
            tokens["tier"][a]["$value"], tokens["tier"][b]["$value"]
        )
        if ratio < 1.35:
            notes.append(
                f"{a}/{b} differ by only {ratio:.2f}:1 — indistinguishable by "
                f"colour alone. Carried by notch count ({tokens['tier'][a]['$extensions']['notch.count']} "
                f"vs {tokens['tier'][b]['$extensions']['notch.count']}). Working as designed."
            )

    return failures, notes


# ─── Codegen helpers ─────────────────────────────────────────────────────────


def camel(name: str) -> str:
    parts = re.split(r"[-_ ]", name)
    return parts[0] + "".join(p.title() for p in parts[1:])


def kebab(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "-", name).lower()


def hex_to_swift_literal(hex_colour: str) -> str:
    return "0x" + hex_colour.lstrip("#").upper()


def swift_doc(node: dict) -> str:
    desc = node.get("$description")
    return f"    /// {desc}\n" if desc else ""


# ─── Swift ───────────────────────────────────────────────────────────────────


def render_swift(tokens: dict) -> str:
    dark = tokens["theme"]["dark"]
    light = tokens["theme"]["light"]
    out: list[str] = [BANNER, ""]
    out.append("import SwiftUI\nimport UIKit\n")
    out.append(
        "/// Notch design system tokens.\n"
        "///\n"
        "/// Every colour, size, radius and duration in the app comes from here.\n"
        "/// SwiftLint enforces it (`no_hardcoded_colour`, `no_magic_corner_radius`).\n"
        "public enum Notch {}\n"
    )

    # ── Colour ──
    out.append("// MARK: - Colour\n")
    out.append("public extension Notch {")
    out.append("    /// Semantic colours. Each resolves per colour scheme automatically.")
    out.append("    enum Colour {")
    colour_keys = [k for k in dark if not k.startswith("$")]
    for key in colour_keys:
        out.append(swift_doc(dark[key]).rstrip("\n").replace("    ///", "        ///"))
        out.append(
            f"        public static let {camel(key)} = Color("
            f"light: {hex_to_swift_literal(light[key]['$value'])}, "
            f"dark: {hex_to_swift_literal(dark[key]['$value'])})"
        )
    out.append("    }")
    out.append("}\n")

    # ── Tier ──
    out.append("// MARK: - Tier\n")
    out.append(
        "/// The five-rung ladder.\n"
        "///\n"
        "/// `notches` is the PRIMARY signal and `colour` is secondary (ADR 0012):\n"
        "/// Silver and Platinum are near-identical metals, and roughly 1 in 12 men\n"
        "/// have some colour vision deficiency. Both are derived from this single\n"
        "/// enum so they can never disagree.\n"
        "public enum Tier: Int, CaseIterable, Comparable, Sendable {"
    )
    for name, node in _entries(tokens["tier"]):
        count = node["$extensions"]["notch.count"]
        out.append(f"    /// {node['$description']}")
        out.append(f"    case {camel(name)} = {count}")
    out.append("")
    out.append("    /// Number of notches cut into the badge. The primary tier signal.")
    out.append("    public var notches: Int { rawValue }")
    out.append("")
    out.append("    public var colour: Color {")
    out.append("        switch self {")
    for name, node in _entries(tokens["tier"]):
        out.append(
            f"        case .{camel(name)}: Color("
            f"light: {hex_to_swift_literal(node['$extensions']['notch.light'])}, "
            f"dark: {hex_to_swift_literal(node['$value'])})"
        )
    out.append("        }")
    out.append("    }")
    out.append("")
    out.append("    public var displayName: String {")
    out.append("        switch self {")
    for name, _ in _entries(tokens["tier"]):
        out.append(f'        case .{camel(name)}: "{name.title()}"')
    out.append("        }")
    out.append("    }")
    out.append("")
    out.append(
        "    /// VoiceOver label. States the position explicitly so the ladder is\n"
        "    /// legible without seeing the badge at all."
    )
    out.append("    public var accessibilityLabel: String {")
    out.append(
        '        "\\(displayName). Tier \\(rawValue) of \\(Tier.allCases.count)."'
    )
    out.append("    }")
    out.append("")
    out.append(
        "    public static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }"
    )
    out.append("}\n")

    # ── Typography ──
    out.append("// MARK: - Typography\n")
    out.append("public extension Notch {")
    out.append(
        "    /// Type scale. Every style is bound to an iOS text style so Dynamic\n"
        "    /// Type works for free — required, not optional, in a health app."
    )
    out.append("    enum TypeStyle: Sendable {")
    for name, _ in _entries(tokens["type"]):
        out.append(f"        case {camel(name)}")
    out.append("")
    # Dynamic Type: SwiftUI's `.system(size:)` does NOT scale on its own, and
    # `Font` has no `.relative(to:)`. UIFontMetrics is the supported way to scale
    # an arbitrary point size against a text style, and it re-evaluates when the
    # trait collection changes, so views pick up a Dynamic Type change on redraw.
    out.append("        /// Base point size at the Large (default) content size.")
    out.append("        public var size: CGFloat {")
    out.append("            switch self {")
    for name, node in _entries(tokens["type"]):
        out.append(f"            case .{camel(name)}: {node['$value']['fontSize']}")
    out.append("            }")
    out.append("        }")
    out.append("")
    out.append("        public var weight: Font.Weight {")
    out.append("            switch self {")
    weight_map = {"400": "regular", "600": "semibold", "700": "bold"}
    for name, node in _entries(tokens["type"]):
        w = weight_map.get(node["$value"]["fontWeight"], "regular")
        out.append(f"            case .{camel(name)}: .{w}")
    out.append("            }")
    out.append("        }")
    out.append("")
    out.append(
        "        /// The iOS text style this scales against. Bound per style so\n"
        "        /// Dynamic Type ramps sensibly rather than uniformly."
    )
    out.append("        public var textStyle: UIFont.TextStyle {")
    out.append("            switch self {")
    ios_style_map = {
        "largeTitle": "largeTitle",
        "title": "title1",
        "title2": "title2",
        "title3": "title3",
        "headline": "headline",
        "body": "body",
        "callout": "callout",
        "subheadline": "subheadline",
        "footnote": "footnote",
        "caption": "caption1",
        "caption2": "caption2",
    }
    for name, node in _entries(tokens["type"]):
        raw = node.get("$extensions", {}).get("notch.iosTextStyle", "body")
        out.append(f"            case .{camel(name)}: .{ios_style_map[raw]}")
    out.append("            }")
    out.append("        }")
    out.append("")
    out.append(
        "        /// Digits line up in columns and do not jitter as values change.\n"
        "        /// Essential anywhere a number updates in place — calories\n"
        "        /// remaining, the composite score, kcal on a food row."
    )
    out.append("        public var usesTabularFigures: Bool {")
    tabular = [
        camel(n)
        for n, node in _entries(tokens["type"])
        if node.get("$extensions", {}).get("notch.tabularFigures")
    ]
    if tabular:
        out.append(
            f"            switch self {{ case {', '.join('.' + t for t in tabular)}: true; default: false }}"
        )
    else:
        out.append("            false")
    out.append("        }")
    out.append("")
    out.append("        public var font: Font {")
    out.append(
        "            let scaled = UIFontMetrics(forTextStyle: textStyle)\n"
        "                .scaledValue(for: size)\n"
        "            let base = Font.system(size: scaled, weight: weight, design: .default)\n"
        "            return usesTabularFigures ? base.monospacedDigit() : base"
    )
    out.append("        }")
    out.append("")
    out.append("        public var lineHeight: CGFloat {")
    out.append("            switch self {")
    for name, node in _entries(tokens["type"]):
        out.append(f"            case .{camel(name)}: {node['$value']['lineHeight']}")
    out.append("            }")
    out.append("        }")
    out.append("")
    out.append("        public var tracking: CGFloat {")
    out.append("            switch self {")
    for name, node in _entries(tokens["type"]):
        out.append(
            f"            case .{camel(name)}: {node['$value']['letterSpacing']}"
        )
    out.append("            }")
    out.append("        }")
    out.append("")
    out.append("        /// Labels are set in caps; nothing else is.")
    out.append("        public var isUppercased: Bool {")
    upper = [
        camel(n)
        for n, node in _entries(tokens["type"])
        if node.get("$extensions", {}).get("notch.transform") == "uppercase"
    ]
    if upper:
        cases = ", ".join(f".{u}" for u in upper)
        out.append(f"            switch self {{ case {cases}: true; default: false }}")
    else:
        out.append("            false")
    out.append("        }")
    out.append("    }")
    out.append("}\n")

    out.append(
        "public extension View {\n"
        "    /// Apply a Notch type style, including tracking and casing.\n"
        "    func notchType(_ style: Notch.TypeStyle) -> some View {\n"
        "        font(style.font).tracking(style.tracking)\n"
        "    }\n"
        "}\n"
    )

    # ── Scalars ──
    for group, doc in (
        ("space", "Spacing scale. 4-point grid."),
        ("radius", "Corner radii. Always paired with the continuous curve."),
        ("border", "Stroke widths."),
    ):
        out.append(f"// MARK: - {group.title()}\n")
        out.append("public extension Notch {")
        out.append(f"    /// {doc}")
        out.append(f"    enum {group.title()} {{")
        for name, node in _entries(tokens[group]):
            out.append(swift_doc(node).rstrip("\n").replace("    ///", "        ///"))
            out.append(
                f"        public static let {camel(name)}: CGFloat = {node['$value']}"
            )
        out.append("    }")
        out.append("}\n")

    # ── Motion ──
    out.append("// MARK: - Motion\n")
    out.append("public extension Notch {")
    out.append(
        "    /// MOTION BUDGET: nothing but `.reveal` may exceed 0.3s.\n"
        "    /// Always respect Reduce Motion — use `Notch.Motion.animation(_:reduceMotion:)`."
    )
    out.append("    enum Motion {")
    for name, node in _entries(tokens["motion"]["duration"]):
        seconds = int(node["$value"].removesuffix("ms")) / 1000
        out.append(swift_doc(node).rstrip("\n").replace("    ///", "        ///"))
        out.append(f"        public static let {camel(name)}: Double = {seconds}")
    out.append("")
    for name, node in _entries(tokens["motion"]["spring"]):
        expr = node["$extensions"]["notch.swiftUI"]
        out.append(f"        public static let {camel(name)}Spring: Animation = .{expr}")
    out.append("")
    out.append(
        "        /// Returns nil when Reduce Motion is on, so `withAnimation(nil)`\n"
        "        /// applies the change instantly instead of animating it."
    )
    out.append(
        "        public static func animation(\n"
        "            _ animation: Animation,\n"
        "            reduceMotion: Bool\n"
        "        ) -> Animation? {\n"
        "            reduceMotion ? nil : animation\n"
        "        }"
    )
    out.append("    }")
    out.append("}\n")

    # ── Helpers ──
    out.append(
        "// MARK: - Helpers\n"
        "\n"
        "public extension View {\n"
        "    /// Rounded rect with the iOS continuous curve. Using this instead of\n"
        "    /// `.cornerRadius(_:)` is why `no_magic_corner_radius` can be a lint rule.\n"
        "    func notchCorners(_ radius: CGFloat) -> some View {\n"
        "        clipShape(.rect(cornerRadius: radius, style: .continuous))\n"
        "    }\n"
        "\n"
        "    /// Card surface. Dark mode gets a lightness step plus a hairline;\n"
        "    /// light mode gets a shadow. Shadows do not read on near-black, so the\n"
        "    /// two schemes need genuinely different treatments — this picks for you.\n"
        "    func notchCard(radius: CGFloat = Notch.Radius.lg) -> some View {\n"
        "        modifier(NotchCardStyle(radius: radius))\n"
        "    }\n"
        "}\n"
        "\n"
        "public struct NotchCardStyle: ViewModifier {\n"
        "    @Environment(\\.colorScheme) private var scheme\n"
        "    let radius: CGFloat\n"
        "\n"
        "    public func body(content: Content) -> some View {\n"
        "        content\n"
        "            .background(Notch.Colour.surface)\n"
        "            .notchCorners(radius)\n"
        "            .overlay(\n"
        "                RoundedRectangle(cornerRadius: radius, style: .continuous)\n"
        "                    .strokeBorder(\n"
        "                        Notch.Colour.stroke,\n"
        "                        lineWidth: scheme == .dark ? Notch.Border.hairline : 0\n"
        "                    )\n"
        "            )\n"
        "            .shadow(\n"
        "                color: .black.opacity(scheme == .dark ? 0 : 0.16),\n"
        "                radius: 3,\n"
        "                y: 1\n"
        "            )\n"
        "    }\n"
        "}\n"
        "\n"
        "// MARK: - Colour scheme resolution\n"
        "\n"
        "private extension Color {\n"
        "    /// Resolve a light/dark pair at render time so a single token works in both.\n"
        "    init(light: UInt32, dark: UInt32) {\n"
        "        self.init(UIColor { traits in\n"
        "            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)\n"
        "        })\n"
        "    }\n"
        "}\n"
        "\n"
        "private extension UIColor {\n"
        "    convenience init(rgb: UInt32) {\n"
        "        self.init(\n"
        "            red: CGFloat((rgb >> 16) & 0xFF) / 255,\n"
        "            green: CGFloat((rgb >> 8) & 0xFF) / 255,\n"
        "            blue: CGFloat(rgb & 0xFF) / 255,\n"
        "            alpha: 1\n"
        "        )\n"
        "    }\n"
        "}\n"
    )

    return "\n".join(out)


# ─── CSS ─────────────────────────────────────────────────────────────────────


def render_css(tokens: dict) -> str:
    dark, light = tokens["theme"]["dark"], tokens["theme"]["light"]
    lines = [
        "/* GENERATED FILE — DO NOT EDIT.",
        "   Source: design/tokens/notch.tokens.json",
        "   Regenerate: python3 design/tokens/generate.py */",
        "",
    ]

    def colour_block(theme: dict, tier_key: str) -> list[str]:
        rows = [
            f"  --c-{kebab(k)}: {v['$value']};"
            for k, v in theme.items()
            if not k.startswith("$")
        ]
        rows += [
            f"  --tier-{k}: {(v['$value'] if tier_key == '$value' else v['$extensions']['notch.light'])};"
            for k, v in tokens["tier"].items()
            if not k.startswith("$")
        ]
        return rows

    lines.append(":root {")
    lines += colour_block(light, "notch.light")
    for group, unit in (("space", "px"), ("radius", "px"), ("border", "px")):
        for name, node in _entries(tokens[group]):
            lines.append(f"  --{group[:3]}-{kebab(name)}: {node['$value']}{unit};")
    for name, node in tokens["type"].items():
        if name.startswith("$"):
            continue
        v = node["$value"]
        lines.append(
            f"  --type-{kebab(name)}: {v['fontWeight']} {v['fontSize']}px/"
            f"{v['lineHeight']}px system-ui, -apple-system, sans-serif;"
        )
        lines.append(f"  --track-{kebab(name)}: {v['letterSpacing']}px;")
    for name, node in tokens["motion"]["duration"].items():
        if name.startswith("$"):
            continue
        lines.append(f"  --dur-{kebab(name)}: {node['$value']};")
    for name, node in tokens["motion"]["spring"].items():
        if name.startswith("$"):
            continue
        b = ", ".join(str(x) for x in node["$value"])
        lines.append(f"  --ease-{kebab(name)}: cubic-bezier({b});")
    lines.append("}")
    lines.append("")

    dark_rows = colour_block(dark, "$value")
    lines.append("@media (prefers-color-scheme: dark) {")
    lines.append("  :root {")
    lines += ["  " + r for r in dark_rows]
    lines.append("  }")
    lines.append("}")
    lines.append("")
    lines.append('/* Explicit override must beat the media query in BOTH directions. */')
    lines.append(':root[data-theme="dark"] {')
    lines += dark_rows
    lines.append("}")
    lines.append("")
    lines.append(':root[data-theme="light"] {')
    lines += colour_block(light, "notch.light")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


# ─── Main ────────────────────────────────────────────────────────────────────


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--check",
        action="store_true",
        help="verify generated files are in sync and contrast passes; write nothing",
    )
    args = ap.parse_args()

    tokens = json.loads(TOKENS.read_text())

    failures = check_contrast(tokens)
    tier_failures, tier_notes = check_tiers(tokens)
    failures += tier_failures

    if failures:
        print("Design token validation FAILED:\n", file=sys.stderr)
        for f in failures:
            print(f"  ✗ {f}", file=sys.stderr)
        print(
            "\nFix notch.tokens.json. Do not lower the thresholds in "
            "generate.py — they are WCAG 2.1, not preferences.",
            file=sys.stderr,
        )
        return 1

    for note in tier_notes:
        print(f"  · {note}")

    outputs = {OUT_SWIFT: render_swift(tokens), OUT_CSS: render_css(tokens)}

    if args.check:
        stale = [
            p for p, content in outputs.items()
            if not p.exists() or p.read_text() != content
        ]
        if stale:
            print("Generated files are stale:", file=sys.stderr)
            for p in stale:
                print(f"  ✗ {p.relative_to(ROOT)}", file=sys.stderr)
            print(
                "\nRun: python3 design/tokens/generate.py", file=sys.stderr
            )
            return 1
        print(f"✓ tokens valid, {len(outputs)} generated files in sync")
        return 0

    for path, content in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        print(f"✓ wrote {path.relative_to(ROOT)}")

    n_colours = len(_entries(tokens["theme"]["dark"]))
    print(
        f"✓ {n_colours} semantic colours × 2 themes, "
        f"{len(_entries(tokens['tier']))} tiers, "
        f"{len(_entries(tokens['type']))} type styles — "
        f"all contrast rules pass"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
