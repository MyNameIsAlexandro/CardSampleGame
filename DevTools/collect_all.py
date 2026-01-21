import os

# --- НАСТРОЙКИ ПУТЕЙ ---

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "Output")

# Папки, которые игнорируем при сканировании КОДА
IGNORE_DIRS_CODE = {
    '.git', '.build', 'DerivedData', 'Assets.xcassets', 
    'CardSampleGame.xcodeproj', '.xcworkspace', '.idea',
    'CardSampleGameTests', 'Docs', 'DevTools', '__pycache__',
    'ru.lproj', 'en.lproj', 'ContentPacks', 'Новые требования' 
}

# Файлы из корня, которые нужно добавить в DOCS_DUMP
ROOT_DOCS_TO_INCLUDE = [
    "AUDIT_ENGINE_FIRST_v1_1.md",
    "CHANGELOG_ENGINE_FIRST.md"
]

# Папки с документацией (сканируем их содержимое для DOCS_DUMP)
DOC_DIRS = [
    "Docs",
    "Новые требования"
]

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

def collect_files(scan_dirs, output_filename, extensions, ignore_set=None, extra_files=None):
    if isinstance(scan_dirs, str): scan_dirs = [scan_dirs] # Превращаем в список, если строка
    if ignore_set is None: ignore_set = set()
    if extra_files is None: extra_files = []
    
    full_output_path = os.path.join(OUTPUT_DIR, output_filename)
    print(f"📦 Собираем {output_filename}...")
    
    with open(full_output_path, 'w', encoding='utf-8') as outfile:
        # Заголовок
        source_desc = ", ".join(scan_dirs)
        write_header(outfile, "DUMP GENERATED", source_desc)
        
        # 1. Структура
        outfile.write("=== FILE STRUCTURE ===\n")
        
        # Доп файлы из корня
        for extra in extra_files:
            extra_path = os.path.join(PROJECT_ROOT, extra)
            if os.path.exists(extra_path):
                outfile.write(f"{extra} (Root File)\n")

        # Обход папок
        for scan_dir_rel in scan_dirs:
            scan_path = os.path.join(PROJECT_ROOT, scan_dir_rel)
            if os.path.exists(scan_path):
                # Если это корень (PROJECT_ROOT), не пишем имя папки как родителя
                is_root = (scan_path == PROJECT_ROOT)
                
                for root, dirs, files in os.walk(scan_path):
                    dirs[:] = [d for d in dirs if d not in ignore_set] # ФИКС: ignore_set вместо ignore_dirs
                    
                    # Красивый отступ
                    rel_root = os.path.relpath(root, PROJECT_ROOT)
                    if rel_root == ".": rel_root = ""
                    
                    level = rel_root.count(os.sep)
                    indent = ' ' * 4 * level
                    
                    # Пишем имя папки, только если это не точка
                    if rel_root:
                        outfile.write(f"{indent}{os.path.basename(root)}/\n")
                        subindent = ' ' * 4 * (level + 1)
                    else:
                        subindent = ''

                    for f in sorted(files):
                        if any(f.endswith(ext) for ext in extensions):
                            outfile.write(f"{subindent}{f}\n")
            else:
                 outfile.write(f"(Directory not found: {scan_dir_rel})\n")

        outfile.write("\n=== FILE CONTENTS ===\n")

        # 2. Контент файлов
        for scan_dir_rel in scan_dirs:
            scan_path = os.path.join(PROJECT_ROOT, scan_dir_rel)
            if os.path.exists(scan_path):
                for root, dirs, files in os.walk(scan_path):
                    dirs[:] = [d for d in dirs if d not in ignore_set] # ФИКС
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
    
    # 1. КОД (сканируем корень, исключаем лишнее)
    collect_files(
        scan_dirs=".", 
        output_filename="PROJECT_CODE_DUMP.txt",
        extensions=[".swift"], 
        ignore_set=IGNORE_DIRS_CODE
    )

    # 2. ТЕСТЫ
    collect_files(
        scan_dirs="CardSampleGameTests", 
        output_filename="TESTS_DUMP.txt", 
        extensions=[".swift"]
    )

    # 3. ДОКУМЕНТАЦИЯ (Docs + Новые требования + файлы из корня)
    collect_files(
        scan_dirs=DOC_DIRS, 
        output_filename="DOCS_DUMP.txt", 
        extensions=[".md", ".txt", ".json"],
        extra_files=ROOT_DOCS_TO_INCLUDE
    )

    print(f"\n✅ ГОТОВО! Файлы лежат в папке: DevTools/Output/")
