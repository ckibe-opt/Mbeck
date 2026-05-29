import os
import sys

# Ensure UTF-8 output
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

home_screen_path = r"C:\dev\Mbeckapp_seller-4ab538ed\lib\screens\home_screen.dart"

with open(home_screen_path, "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()

def print_context(line_num, radius=10):
    start = max(0, line_num - radius - 1)
    end = min(len(lines), line_num + radius)
    print(f"=== Context around line {line_num} ===")
    for idx in range(start, end):
        print(f"{idx+1}: {lines[idx].rstrip()}")
    print("\n")

for l in [896, 1025, 1031, 1048, 1054, 1141, 1147]:
    print_context(l)
