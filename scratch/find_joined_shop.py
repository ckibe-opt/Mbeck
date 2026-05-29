import os

def search_ref():
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    if 'completeOnboardingForJoinedShop' in content:
                        print(f"Found in {path}")

if __name__ == '__main__':
    search_ref()
