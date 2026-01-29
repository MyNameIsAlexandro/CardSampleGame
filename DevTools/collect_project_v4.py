import os

# --- НАСТРОЙКИ ---

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "Output")

# Игнорируем системные папки и билды
IGNORE_DIRS = {
    '.git', '.build', 'DerivedData', 'Assets.xcassets', 
    'CardSampleGame.xcodeproj', '.xcworkspace', '.idea',
    '__pycache__', 'DevTools', 'Output', '.swiftpm'
}

# --- ФУНКЦИИ ---

def ensure_output_dir():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

def write_header(outfile, title, source_desc):
    outfile.write(f"=== {title} ===\n")
    outfile.write(f"Source: {source_desc}\n\n")

def write_file_content(outfile, filepath, base_path_for_rel):
    rel_path = os.path.relpath(filepath, base_path_for_rel)
    outfile.write(f"\n// ==========================================\n")
    outfile.write(f"// FILE: {rel_path}\n")
    outfile.write(f"// ==========================================\n\n")
    try:
        with open(filepath, 'r', encoding='utf-8') as infile:
            outfile.write(infile.read())
    except Exception as e:
        outfile.write(f"// Error reading file: {e}")
    outfile.write("\n")

def collect_files(output_filename, extensions, include_paths=None, exclude_paths=None):
    full_output_path = os.path.join(OUTPUT_DIR, output_filename)
    print(f"📦 Собираем {output_filename}...")
    
    with open(full_output_path, 'w', encoding='utf-8') as outfile:
        write_header(outfile, "DUMP GENERATED", PROJECT_ROOT)
        
        # 1. Структура файлов (Дерево)
        outfile.write("=== FILE STRUCTURE ===\n")
        for root, dirs, files in os.walk(PROJECT_ROOT):
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            
            # Логика фильтрации путей
            rel_root = os.path.relpath(root, PROJECT_ROOT)
            if rel_root == ".": rel_root = ""
            
            # Если задан include_paths, пропускаем всё, что не внутри них
            if include_paths:
                if not any(rel_root.startswith(p) or p.startswith(rel_root) for p in include_paths):
                    continue
            
            # Если задан exclude_paths, пропускаем их
            if exclude_paths:
                if any(rel_root.startswith(p) for p in exclude_paths):
                    continue

            level = rel_root.count(os.sep)
            indent = ' ' * 4 * level
            if rel_root:
                outfile.write(f"{indent}{os.path.basename(root)}/\n")
            
            subindent = ' ' * 4 * (level + 1)
            for f in sorted(files):
                if any(f.endswith(ext) for ext in extensions):
                    outfile.write(f"{subindent}{f}\n")

        outfile.write("\n=== FILE CONTENTS ===\n")

        # 2. Содержимое файлов
        for root, dirs, files in os.walk(PROJECT_ROOT):
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            
            rel_root = os.path.relpath(root, PROJECT_ROOT)
            if rel_root == ".": rel_root = ""

            if include_paths:
                if not any(rel_root.startswith(p) for p in include_paths):
                    continue

            if exclude_paths:
                if any(rel_root.startswith(p) for p in exclude_paths):
                    continue

            for filename in sorted(files):
                if any(filename.endswith(ext) for ext in extensions):
                    filepath = os.path.join(root, filename)
                    write_file_content(outfile, filepath, PROJECT_ROOT)

# --- ЗАПУСК ---

if __name__ == "__main__":
    ensure_output_dir()
    
    # 1. КОД ПРОЕКТА (Engine + App)
    # Собираем Swift файлы из Packages (движок) и корня (приложение)
    # Исключаем тесты из кода
    collect_files(
        output_filename="PROJECT_CODE_DUMP.txt",
        extensions=[".swift"],
        include_paths=["Packages", "Sources", "App", "ViewModels", "Views", "Models", "Utilities"], # Адаптивно ищем везде
        exclude_paths=["Tests", "CardSampleGameTests", "Packages/TwilightEngine/Tests"]
    )

    # 2. ДАННЫЕ (JSON)
    # Баланс, конфиги, манифесты (ищем и в пакетах, и в App/Resources)
    collect_files(
        output_filename="DATA_DUMP.txt",
        extensions=[".json"],
        exclude_paths=["DerivedData", ".swiftpm"]
    )

    # 3. ТЕСТЫ
    # Собираем тесты и из основного таргета, и из Swift Package
    collect_files(
        output_filename="TESTS_DUMP.txt",
        extensions=[".swift"],
        include_paths=["CardSampleGameTests", "Packages/TwilightEngine/Tests"]
    )

    # 4. ДОКУМЕНТАЦИЯ
    collect_files(
        output_filename="DOCS_DUMP.txt",
        extensions=[".md", ".txt"],
        exclude_paths=["DevTools/Output"]
    )

    print(f"\n✅ ГОТОВО! 4 файла созданы в DevTools/Output/")
