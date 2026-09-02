#!/usr/bin/env python3
"""
Generate Swift and CSS from ninety.tokens.json, and verify the design system's
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
     chevron count and flags any adjacent pair that is too close in luminance to
     tell apart — which is the whole reason ADR 0012 encodes tier as a count.
     The check is expected to FLAG Silver/Platinum; that is the point. It fails
     only if the chevron counts are wrong, because the count is the real signal.

No third-party dependencies. Runs on a clean Python 3.11.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOKENS = ROOT / "design" / "tokens" / "ninety.tokens.json"
OUT_SWIFT = ROOT / "design" / "generated" / "DesignTokens.generated.swift"
OUT_CSS = ROOT / "design" / "generated" / "tokens.generated.css"
BRIEF_TEMPLATE = ROOT / "design" / "spec" / "brief.template.md"
OUT_BRIEF = ROOT / "design" / "generated" / "claude-design-brief.md"
ASSETS = ROOT / "Ninety" / "Assets.xcassets"

# Two colours the app needs *outside* Swift: the global tint (which UIKit
# reads before any of our code runs) and the launch screen ground (drawn by
# the system before the process exists). An asset catalogue is the only place
# either can live — so they are generated here too, rather than being the two
# hand-typed hex values that quietly drift from the rest of the palette.
ASSET_COLOURS = {
    "AccentColor": ("accent", "Global tint. UIKit reads it before any Swift runs."),
    "LaunchCanvas": ("canvas", "Launch screen ground, drawn before the process exists."),
}

BANNER = (
    "// GENERATED FILE — DO NOT EDIT.\n"
    "// Source: design/tokens/ninety.tokens.json\n"
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
            tier["$extensions"]["ninety.light"],
            tokens["theme"]["light"]["canvas"]["$value"],
        )
        for label, ratio in (("dark", dark_ratio), ("light", light_ratio)):
            if ratio < MIN_TIER_ON_CANVAS:
                failures.append(
                    f"tier.{tier_name} on {label} canvas is {ratio:.2f}:1, "
                    f"needs {MIN_TIER_ON_CANVAS}:1"
                )

    return failures


FONT_DIR = ROOT / "Ninety" / "Resources" / "Fonts"


def font_name(tokens: dict, node: dict) -> str:
    """The PostScript name a type style must ask SwiftUI for.

    Weight lives in the *file*, not in a `.weight()` modifier: applying one on
    top of a custom face makes iOS synthesise a bolder outline, which is a
    visibly worse rendering of a weight the family already ships.
    """
    ext = node.get("$extensions", {})
    role = ext.get("ninety.fontRole", "ui")
    weight = node["$value"]["fontWeight"]
    return tokens["font"][role]["$extensions"]["ninety.postScriptNames"][weight]


def check_fonts(tokens: dict) -> list[str]:
    """Fail on a type style the bundled faces cannot actually render.

    Three ways this goes wrong silently, and iOS reports none of them — it just
    falls back to San Francisco and the Matchday world quietly becomes a
    generic SwiftUI app:

      · a style asks for a weight the family does not ship
      · a metric style is put on the condensed face, which has no `tnum`, so
        its digits jitter as the value updates
      · the .ttf naming the token file promises is not in the bundle
    """
    failures: list[str] = []

    for name, node in _entries(tokens["type"]):
        ext = node.get("$extensions", {})
        role = ext.get("ninety.fontRole", "ui")
        if role not in tokens["font"]:
            failures.append(f"type.{name}: unknown font role {role!r}")
            continue

        family = tokens["font"][role]
        names = family["$extensions"]["ninety.postScriptNames"]
        weight = node["$value"]["fontWeight"]
        if weight not in names:
            failures.append(
                f"type.{name}: {family['$value']} does not ship weight {weight} "
                f"(has {', '.join(sorted(names))}). Pick a shipped weight or bundle the file."
            )
            continue

        if ext.get("ninety.tabularFigures") and role == "broadcast":
            failures.append(
                f"type.{name} wants tabular figures on {family['$value']}, which has no "
                f"tnum table. Digits that update in place must use the ui role."
            )

        ttf = FONT_DIR / f"{names[weight]}.ttf"
        if not ttf.exists():
            failures.append(
                f"type.{name} needs {ttf.relative_to(ROOT)}, which is not in the bundle"
            )

    return failures


def check_tiers(tokens: dict) -> tuple[list[str], list[str]]:
    """Verify chevron counts are 1..5 in ladder order. Returns (failures, notes)."""
    failures: list[str] = []
    notes: list[str] = []

    ladder = ["bronze", "silver", "gold", "platinum", "diamond"]
    if [k for k, _ in _entries(tokens["tier"])] != ladder:
        failures.append(
            "tier order in ninety.tokens.json must be "
            f"{' -> '.join(ladder)} (§03 ladder order)"
        )
        return failures, notes

    for expected, name in enumerate(ladder, start=1):
        actual = tokens["tier"][name]["$extensions"]["ninety.count"]
        if actual != expected:
            failures.append(
                f"tier.{name} has ninety.count {actual}, expected {expected}. "
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
                f"colour alone. Carried by chevron count ({tokens['tier'][a]['$extensions']['ninety.count']} "
                f"vs {tokens['tier'][b]['$extensions']['ninety.count']}). Working as designed."
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


def render_colorset(tokens: dict, token_name: str) -> str:
    """One .colorset, light and dark, in the catalogue's own JSON.

    No header comment: this format is strict JSON, so the note explaining why
    each of these exists lives on ASSET_COLOURS instead.
    """

    def components(hex_colour: str) -> dict:
        h = hex_colour.lstrip("#")
        return {
            "alpha": "1.000",
            "red": f"0x{h[0:2].upper()}",
            "green": f"0x{h[2:4].upper()}",
            "blue": f"0x{h[4:6].upper()}",
        }

    def entry(hex_colour: str, dark: bool) -> dict:
        node = {"idiom": "universal"}
        if dark:
            node["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
        node["color"] = {"color-space": "srgb", "components": components(hex_colour)}
        return node

    body = {
        "colors": [
            entry(tokens["theme"]["light"][token_name]["$value"], dark=False),
            entry(tokens["theme"]["dark"][token_name]["$value"], dark=True),
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"localizable": False},
    }
    return json.dumps(body, indent=2) + "\n"


# ─── Swift ───────────────────────────────────────────────────────────────────


def render_swift(tokens: dict) -> str:
    dark = tokens["theme"]["dark"]
    light = tokens["theme"]["light"]
    out: list[str] = [BANNER, ""]
    out.append("import SwiftUI\nimport UIKit\n")
    out.append(
        "/// Ninety design system tokens.\n"
        "///\n"
        "/// Every colour, size, radius and duration in the app comes from here.\n"
        "/// SwiftLint enforces it (`no_hardcoded_colour`, `no_magic_corner_radius`).\n"
        "public enum Ninety {}\n"
    )

    # ── Colour ──
    out.append("// MARK: - Colour\n")
    out.append("public extension Ninety {")
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
        "/// `chevrons` is the PRIMARY signal and `colour` is secondary (ADR 0012):\n"
        "/// Silver and Platinum are near-identical metals, and roughly 1 in 12 men\n"
        "/// have some colour vision deficiency. Both are derived from this single\n"
        "/// enum so they can never disagree.\n"
        "public enum Tier: Int, CaseIterable, Comparable, Sendable {"
    )
    for name, node in _entries(tokens["tier"]):
        count = node["$extensions"]["ninety.count"]
        out.append(f"    /// {node['$description']}")
        out.append(f"    case {camel(name)} = {count}")
    out.append("")
    out.append("    /// Number of chevrons in the badge. The primary tier signal.")
    out.append("    public var chevrons: Int { rawValue }")
    out.append("")
    out.append("    public var colour: Color {")
    out.append("        switch self {")
    for name, node in _entries(tokens["tier"]):
        out.append(
            f"        case .{camel(name)}: Color("
            f"light: {hex_to_swift_literal(node['$extensions']['ninety.light'])}, "
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
    out.append("public extension Ninety {")
    out.append(
        "    /// Type scale. Every style is bound to an iOS text style so Dynamic\n"
        "    /// Type works for free — required, not optional, in a health app."
    )
    # CaseIterable is synthesised only in the file that declares the enum, so it
    # has to be here: BrandFont walks every style to verify the bundled faces
    # actually registered.
    out.append("    enum TypeStyle: String, CaseIterable, Sendable {")
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
    out.append(
        "        /// Informational only — the weight is baked into `fontName`.\n"
        "        /// Do NOT apply this with `.weight()` on top of the custom face:\n"
        "        /// iOS would synthesise a bolder outline over a weight the family\n"
        "        /// already ships properly drawn."
    )
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
        raw = node.get("$extensions", {}).get("ninety.iosTextStyle", "body")
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
        if node.get("$extensions", {}).get("ninety.tabularFigures")
    ]
    if tabular:
        out.append(
            f"            switch self {{ case {', '.join('.' + t for t in tabular)}: true; default: false }}"
        )
    else:
        out.append("            false")
    out.append("        }")
    out.append("")
    out.append(
        "        /// The bundled face, by PostScript name. The static builds\n"
        "        /// have inconsistent *family* names; PostScript names are exact,\n"
        "        /// and an exact name is the difference between the Matchday world\n"
        "        /// and a silent fallback to San Francisco."
    )
    out.append("        public var fontName: String {")
    out.append("            switch self {")
    for name, node in _entries(tokens["type"]):
        out.append(f'            case .{camel(name)}: "{font_name(tokens, node)}"')
    out.append("            }")
    out.append("        }")
    out.append("")
    out.append(
        "        /// The SwiftUI text style the face scales against.\n"
        "        /// `Font.custom(_:size:relativeTo:)` is what makes a bundled face\n"
        "        /// honour Dynamic Type — a plain `Font.custom(_:size:)` does not\n"
        "        /// scale at all, and that failure is invisible until someone with\n"
        "        /// a larger reading size opens the app (ADR 0015)."
    )
    out.append("        public var scalesAgainst: Font.TextStyle {")
    out.append("            switch self {")
    for name, node in _entries(tokens["type"]):
        raw = node.get("$extensions", {}).get("ninety.iosTextStyle", "body")
        out.append(f"            case .{camel(name)}: .{raw}")
    out.append("            }")
    out.append("        }")
    out.append("")
    out.append("        public var font: Font {")
    out.append(
        "            let base = Font.custom(fontName, size: size, relativeTo: scalesAgainst)\n"
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
        if node.get("$extensions", {}).get("ninety.transform") == "uppercase"
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
        "    /// Apply a Ninety type style: face, Dynamic Type scaling, tracking and casing.\n"
        "    ///\n"
        "    /// Casing is applied here rather than in the string so the copy deck and\n"
        "    /// the accessibility label both keep their sentence case — VoiceOver\n"
        "    /// spells out an all-caps string letter by letter.\n"
        "    func ninetyType(_ style: Ninety.TypeStyle) -> some View {\n"
        "        font(style.font)\n"
        "            .tracking(style.tracking)\n"
        "            .textCase(style.isUppercased ? .uppercase : nil)\n"
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
        out.append("public extension Ninety {")
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
    out.append("public extension Ninety {")
    out.append(
        "    /// MOTION BUDGET: nothing but `.reveal` may exceed 0.3s.\n"
        "    /// Always respect Reduce Motion — use `Ninety.Motion.animation(_:reduceMotion:)`."
    )
    out.append("    enum Motion {")
    for name, node in _entries(tokens["motion"]["duration"]):
        seconds = int(node["$value"].removesuffix("ms")) / 1000
        out.append(swift_doc(node).rstrip("\n").replace("    ///", "        ///"))
        out.append(f"        public static let {camel(name)}: Double = {seconds}")
    out.append("")
    for name, node in _entries(tokens["motion"]["spring"]):
        expr = node["$extensions"]["ninety.swiftUI"]
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
        "    func ninetyCorners(_ radius: CGFloat) -> some View {\n"
        "        clipShape(.rect(cornerRadius: radius, style: .continuous))\n"
        "    }\n"
        "\n"
        "    /// Card surface. Dark mode gets a lightness step plus a hairline;\n"
        "    /// light mode gets a shadow. Shadows do not read on near-black, so the\n"
        "    /// two schemes need genuinely different treatments — this picks for you.\n"
        "    func ninetyCard(radius: CGFloat = Ninety.Radius.lg) -> some View {\n"
        "        modifier(NinetyCardStyle(radius: radius))\n"
        "    }\n"
        "}\n"
        "\n"
        "public struct NinetyCardStyle: ViewModifier {\n"
        "    @Environment(\\.colorScheme) private var scheme\n"
        "    let radius: CGFloat\n"
        "\n"
        "    public func body(content: Content) -> some View {\n"
        "        content\n"
        "            .background(Ninety.Colour.surface)\n"
        "            .ninetyCorners(radius)\n"
        "            .overlay(\n"
        "                RoundedRectangle(cornerRadius: radius, style: .continuous)\n"
        "                    .strokeBorder(\n"
        "                        Ninety.Colour.stroke,\n"
        "                        lineWidth: scheme == .dark ? Ninety.Border.hairline : 0\n"
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


def _css_family(tokens: dict, node: dict) -> str:
    """The web stack for a style's role, for the artboards and the preview."""
    role = node.get("$extensions", {}).get("ninety.fontRole", "ui")
    family = tokens["font"][role]["$value"]
    fallback = (
        "'Arial Narrow', Arial, sans-serif"
        if role == "broadcast"
        else "system-ui, -apple-system, sans-serif"
    )
    return f"'{family}', {fallback}"


def render_css(tokens: dict) -> str:
    dark, light = tokens["theme"]["dark"], tokens["theme"]["light"]
    lines = [
        "/* GENERATED FILE — DO NOT EDIT.",
        "   Source: design/tokens/ninety.tokens.json",
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
            f"  --tier-{k}: {(v['$value'] if tier_key == '$value' else v['$extensions']['ninety.light'])};"
            for k, v in tokens["tier"].items()
            if not k.startswith("$")
        ]
        return rows

    lines.append(":root {")
    lines += colour_block(light, "ninety.light")
    for group, unit in (("space", "px"), ("radius", "px"), ("border", "px")):
        for name, node in _entries(tokens[group]):
            lines.append(f"  --{group[:3]}-{kebab(name)}: {node['$value']}{unit};")
    for name, node in tokens["type"].items():
        if name.startswith("$"):
            continue
        v = node["$value"]
        lines.append(
            f"  --type-{kebab(name)}: {v['fontWeight']} {v['fontSize']}px/"
            f"{v['lineHeight']}px {_css_family(tokens, node)};"
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
    lines += colour_block(light, "ninety.light")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


# ─── Main ────────────────────────────────────────────────────────────────────


# ─── Paste-into-chat brief ───────────────────────────────────────────────────
# The brief used to be hand-maintained, which meant its hex values were a second
# source of truth that drifted from the first one. The prose lives in
# design/spec/brief.template.md; the tables below are derived, so a token change
# cannot leave the brief quietly wrong.

# Which semantic colours are worth pasting into a chat. The full set is in the
# generated Swift and CSS; a brief that lists all of them is one nobody reads.
BRIEF_COLOURS = [
    "canvas", "surface", "surfaceSunken", "stroke", "strokeStrong",
    "textPrimary", "textSecondary", "textTertiary",
    "accent", "positive", "safety", "critical",
    "chartLine", "chartBaseline", "chartBand",
]


BRIEF_NOTE_BUDGET = 95


def _use_note(node: dict) -> str:
    """The 'Use' column: the token's description, trimmed to fit a chat window.

    Descriptions in the tokens file are long on purpose — they carry the contrast
    measurements and the reasoning. The brief exists to be pasted into a chat, so it
    takes whole leading sentences up to a character budget rather than the lot. The
    full text stays in the tokens file and in the generated Swift doc comments.
    """
    text = (node.get("$description")
            or node.get("$extensions", {}).get("ninety.usage") or "").strip()
    if len(text) <= BRIEF_NOTE_BUDGET:
        return text
    kept: list[str] = []
    for sentence in text.replace(". ", ".\x00").split("\x00"):
        candidate = " ".join(kept + [sentence])
        if kept and len(candidate) > BRIEF_NOTE_BUDGET:
            break
        kept.append(sentence)
    return " ".join(kept).strip()


def render_brief_colour_table(tokens: dict) -> str:
    dark, light = tokens["theme"]["dark"], tokens["theme"]["light"]
    rows = ["| Token | Dark | Light | Use |", "|---|---|---|---|"]
    for name in BRIEF_COLOURS:
        if name not in dark:
            continue
        rows.append(
            f"| {name} | `{dark[name]['$value']}` | `{light[name]['$value']}` "
            f"| {_use_note(dark[name])} |"
        )
    return "\n".join(rows)


def render_brief_type_table(tokens: dict) -> str:
    rows = ["| Style | Size/line | Weight | Use |", "|---|---|---|---|"]
    for name, node in _entries(tokens["type"]):
        v = node["$value"]
        rows.append(
            f"| {name} | {v['fontSize']}/{v['lineHeight']} | {v['fontWeight']} "
            f"| {_use_note(node)} |"
        )
    return "\n".join(rows)


def render_brief(tokens: dict) -> str:
    text = BRIEF_TEMPLATE.read_text()
    for placeholder, table in (
        ("{{COLOUR_TABLE}}", render_brief_colour_table(tokens)),
        ("{{TYPE_TABLE}}", render_brief_type_table(tokens)),
    ):
        if placeholder not in text:
            raise SystemExit(f"brief.template.md is missing {placeholder}")
        text = text.replace(placeholder, table)
    return text


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
    failures += check_fonts(tokens)
    tier_failures, tier_notes = check_tiers(tokens)
    failures += tier_failures

    if failures:
        print("Design token validation FAILED:\n", file=sys.stderr)
        for f in failures:
            print(f"  ✗ {f}", file=sys.stderr)
        print(
            "\nFix ninety.tokens.json. Do not lower the thresholds in "
            "generate.py — they are WCAG 2.1, not preferences.",
            file=sys.stderr,
        )
        return 1

    for note in tier_notes:
        print(f"  · {note}")

    outputs = {
        OUT_SWIFT: render_swift(tokens),
        OUT_CSS: render_css(tokens),
        OUT_BRIEF: render_brief(tokens),
    }
    for asset, (token_name, _why) in ASSET_COLOURS.items():
        outputs[ASSETS / f"{asset}.colorset" / "Contents.json"] = render_colorset(
            tokens, token_name
        )

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
        f"{len(_entries(tokens['type']))} type styles on "
        f"{len(_entries(tokens['font']))} bundled faces — "
        f"all contrast and font rules pass"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
