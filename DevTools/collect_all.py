import os

# --- НАСТРОЙКИ ---

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "Output")

# Папки, которые ПОЛНОСТЬЮ игнорируем (системные/билды)
IGNORE_DIRS_SYSTEM = {
    '.git', '.build', 'DerivedData', 'Assets.xcassets', 
    'CardSampleGame.xcodeproj', '.xcworkspace', '.idea',
    '__pycache__', 'DevTools', 'Output'
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

def collect_files(output_filename, extensions, include_dirs=None, exclude_dirs=None):
    if exclude_dirs is None: exclude_dirs = set()
    
    full_output_path = os.path.join(OUTPUT_DIR, output_filename)
    print(f"📦 Собираем {output_filename} (расширения: {extensions})...")
    
    with open(full_output_path, 'w', encoding='utf-8') as outfile:
        write_header(outfile, "DUMP GENERATED", PROJECT_ROOT)
        
        # 1. Структура (дерево)
        outfile.write("=== FILE STRUCTURE (Relevant Files) ===\n")
        
        for root, dirs, files in os.walk(PROJECT_ROOT):
            # Фильтрация папок
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS_SYSTEM and d not in exclude_dirs]
            
            # Если задан include_dirs, проверяем, находимся ли мы внутри одной из них или это корень
            # Но проще просто сканировать всё и фильтровать файлы, если include_dirs не задан жестко.
            # Для простоты: сканируем всё, кроме игнорируемого.
            
            rel_root = os.path.relpath(root, PROJECT_ROOT)
            if rel_root == ".": rel_root = ""
            
            # Логика фильтрации для конкретного дампа
            # Если мы собираем ТЕСТЫ, мы хотим видеть только папку тестов
            if include_dirs:
                # Проверяем, начинается ли текущий путь с одной из разрешенных папок
                if not any(rel_root.startswith(d) or d.startswith(rel_root) for d in include_dirs):
                     continue

            level = rel_root.count(os.sep)
            indent = ' ' * 4 * level
            
            # Печатаем папку
            if rel_root:
                outfile.write(f"{indent}{os.path.basename(root)}/\n")
            
            # Печатаем файлы
            subindent = ' ' * 4 * (level + 1)
            for f in sorted(files):
                if any(f.endswith(ext) for ext in extensions):
                    outfile.write(f"{subindent}{f}\n")

        outfile.write("\n=== FILE CONTENTS ===\n")

        # 2. Контент
        for root, dirs, files in os.walk(PROJECT_ROOT):
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS_SYSTEM and d not in exclude_dirs]
            
            rel_root = os.path.relpath(root, PROJECT_ROOT)
            if rel_root == ".": rel_root = ""

            if include_dirs:
                if not any(rel_root.startswith(d) for d in include_dirs):
                     continue

            for filename in sorted(files):
                if any(filename.endswith(ext) for ext in extensions):
                    filepath = os.path.join(root, filename)
                    write_file_content(outfile, filepath, PROJECT_ROOT)

# --- ЗАПУСК ---

if __name__ == "__main__":
    ensure_output_dir()
    
    # 1. КОД ПРОЕКТА (.swift)
    # Исключаем тесты из основного дампа кода
    collect_files(
        output_filename="PROJECT_CODE_DUMP.txt",
        extensions=[".swift"],
        exclude_dirs={'CardSampleGameTests'}
    )

    # 2. ДАННЫЕ И КОНФИГИ (.json) - НОВОЕ!
    # Это захватит ContentPacks, Data и любые конфигурации
    collect_files(
        output_filename="DATA_DUMP.txt",
        extensions=[".json"]
    )

    # 3. ТЕСТЫ (.swift)
    collect_files(
        output_filename="TESTS_DUMP.txt",
        extensions=[".swift"],
        include_dirs=['CardSampleGameTests']
    )

    # 4. ДОКУМЕНТАЦИЯ (.md, .txt)
    collect_files(
        output_filename="DOCS_DUMP.txt",
        extensions=[".md", ".txt"],
        exclude_dirs={'DevTools'} # Исключаем дампы в папке DevTools
    )

    print(f"\n✅ ГОТОВО! Теперь у вас 4 файла в папке DevTools/Output/")
