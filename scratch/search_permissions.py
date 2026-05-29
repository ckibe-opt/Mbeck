import os

project_dir = r"C:\dev\Mbeckapp_seller-4ab538ed"
results = []

for root, dirs, files in os.walk(os.path.join(project_dir, "lib")):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
                if "hasPermission" in content:
                    lines = content.splitlines()
                    for idx, line in enumerate(lines):
                        if "hasPermission" in line:
                            results.append(f"{file}:{idx+1}: {line.strip()}")

for r in results:
    print(r)
