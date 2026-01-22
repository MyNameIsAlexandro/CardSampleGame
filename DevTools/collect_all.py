import os

# --- НАСТРОЙКИ ПУТЕЙ ---

# Определяем, где лежит этот скрипт, и где корень проекта
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..")) # На уровень выше
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "Output")

# Папки, которые игнорируем при сканировании КОДА
IGNORE_DIRS = {
    '.git', '.build', 'DerivedData', 'Assets.xcassets', 
    'CardSampleGame.xcodeproj', '.xcworkspace', '.idea',
    'CardSampleGameTests', 'Docs', 'DevTools', '__pycache__'
}

# Дополнительные файлы из корня для включения в документацию
ROOT_DOCS_TO_INCLUDE = [
    "AUDIT_ENGINE_FIRST_v1_1.md",
    "HANDOFF.md"
]

# --- ФУНКЦИИ ---

def ensure_output_dir():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

def write_file_content(outfile, filepath, base_path_for_rel):
    # Делаем путь красивым (относительно корня проекта)
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

def collect_files(scan_dir, output_filename, extensions, ignore_set=None, extra_files=None):
    if ignore_set is None: ignore_set = set()
    if extra_files is None: extra_files = []
    
    full_output_path = os.path.join(OUTPUT_DIR, output_filename)
    print(f"📦 Собираем {output_filename}...")
    
    with open(full_output_path, 'w', encoding='utf-8') as outfile:
        outfile.write(f"=== DUMP GENERATED ===\n")
        outfile.write(f"Source: {scan_dir}\n\n")
        
        # 1. Структура
        outfile.write("=== FILE STRUCTURE ===\n")
        
        # Доп файлы
        for extra in extra_files:
            extra_path = os.path.join(PROJECT_ROOT, extra)
            if os.path.exists(extra_path):
                outfile.write(f"{extra} (Root File)\n")

        # Дерево файлов
        if os.path.exists(scan_dir):
            for root, dirs, files in os.walk(scan_dir):
                dirs[:] = [d for d in dirs if d not in ignore_dirs]
                
                # Красивый отступ для структуры
                rel_root = os.path.relpath(root, PROJECT_ROOT)
                if rel_root == ".": rel_root = ""
                
                level = rel_root.count(os.sep)
                indent = ' ' * 4 * level
                if rel_root:
                    outfile.write(f"{indent}{os.path.basename(root)}/\n")
                    subindent = ' ' * 4 * (level + 1)
                else:
                    subindent = ''

                for f in sorted(files):
                    if any(f.endswith(ext) for ext in extensions):
                        outfile.write(f"{subindent}{f}\n")

        outfile.write("\n=== FILE CONTENTS ===\n")

        # 2. Контент
        if os.path.exists(scan_dir):
            for root, dirs, files in os.walk(scan_dir):
                dirs[:] = [d for d in dirs if d not in ignore_dirs]
                for filename in sorted(files):
                    if any(filename.endswith(ext) for ext in extensions):
                        filepath = os.path.join(root, filename)
                        write_file_content(outfile, filepath, PROJECT_ROOT)

        # 3. Контент доп файлов
        for filename in extra_files:
            filepath = os.path.join(PROJECT_ROOT, filename)
            if os.path.exists(filepath):
                write_file_content(outfile, filepath, PROJECT_ROOT)

# --- ЗАПУСК ---

if __name__ == "__main__":
    ensure_output_dir()
    
    # 1. КОД
    collect_files(
        scan_dir=PROJECT_ROOT,
        output_filename="PROJECT_CODE_DUMP.txt",
        extensions=[".swift"],
        ignore_set=IGNORE_DIRS
    )

    # 2. ТЕСТЫ
    collect_files(
        scan_dir=os.path.join(PROJECT_ROOT, "CardSampleGameTests"),
        output_filename="TESTS_DUMP.txt",
        extensions=[".swift"]
    )

    # 3. ДОКУМЕНТАЦИЯ (+ файлы из корня)
    collect_files(
        scan_dir=os.path.join(PROJECT_ROOT, "Docs"),
        output_filename="DOCS_DUMP.txt",
        extensions=[".md", ".txt", ".json"],
        extra_files=ROOT_DOCS_TO_INCLUDE
    )

    print(f"\n✅ ГОТОВО! Файлы лежат в папке: DevTools/Output/")
