#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_CONFIG = ROOT / 'lib' / 'core' / 'constants' / 'app_config.dart'
PUBSPEC = ROOT / 'pubspec.yaml'


def extract_theme_hex() -> str:
    text = APP_CONFIG.read_text(encoding='utf-8')
    match = re.search(
        r"themePrimaryColorValue\s*=\s*0xFF([0-9A-Fa-f]{6})",
        text,
    )
    if not match:
        raise SystemExit(
            'Could not find `themePrimaryColorValue = 0xFF......` in app_config.dart'
        )
    return f"#{match.group(1).upper()}"


def update_pubspec(hex_color: str) -> bool:
    text = PUBSPEC.read_text(encoding='utf-8')

    pattern_root = re.compile(r"(^\s*color:\s*\")[#0-9A-Fa-f]+(\"\s*$)", re.MULTILINE)
    pattern_android12 = re.compile(
        r"(^\s*android_12:\s*\n\s*color:\s*\")[#0-9A-Fa-f]+(\"\s*$)",
        re.MULTILINE,
    )

    new_text, count_root = pattern_root.subn(rf"\1{hex_color}\2", text, count=1)
    new_text, count_a12 = pattern_android12.subn(rf"\1{hex_color}\2", new_text, count=1)

    if count_root == 0 or count_a12 == 0:
        raise SystemExit(
            'Could not update flutter_native_splash colors in pubspec.yaml. '
            'Expected `color` and `android_12 -> color` entries.'
        )

    if new_text != text:
        PUBSPEC.write_text(new_text, encoding='utf-8')
        return True

    return False


def main() -> None:
    hex_color = extract_theme_hex()
    changed = update_pubspec(hex_color)
    status = 'updated' if changed else 'already in sync'
    print(f'Splash color {status}: {hex_color}')


if __name__ == '__main__':
    main()
