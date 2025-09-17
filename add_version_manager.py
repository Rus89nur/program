#!/usr/bin/env python3
import os
import re
import uuid

def generate_uuid():
    """Генерирует UUID в формате Xcode"""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]

def add_file_to_project(project_path, file_path, group_name="Models"):
    """Добавляет файл в проект Xcode"""
    
    # Читаем project.pbxproj
    with open(project_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Генерируем уникальные ID
    file_ref_id = generate_uuid()
    build_file_id = generate_uuid()
    
    # Имя файла
    filename = os.path.basename(file_path)
    
    # Добавляем в PBXFileReference
    file_ref_pattern = r'(7C452D332E1AE37700A0C1B3 /\* Akt\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = Akt\.swift; sourceTree = "<group>"; \};)'
    file_ref_replacement = f'\\1\n\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};'
    content = re.sub(file_ref_pattern, file_ref_replacement, content)
    
    # Добавляем в PBXBuildFile
    build_file_pattern = r'(7C452D342E1AE37700A0C1B3 /\* Akt\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = 7C452D332E1AE37700A0C1B3 /\* Akt\.swift \*/; \};)'
    build_file_replacement = f'\\1\n\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};'
    content = re.sub(build_file_pattern, build_file_replacement, content)
    
    # Добавляем в группу Models
    group_pattern = r'(7C452CEB2E1ADB3200A0C1B3 /\* Models \*/ = \{\s*isa = PBXGroup;\s*children = \(\s*7C5BD9172E1D5E6300E39873 /\* ViolationsFlow \*/,\s*7C452D332E1AE37700A0C1B3 /\* Akt\.swift \*/,)'
    group_replacement = f'\\1\n\t\t\t\t{file_ref_id} /* {filename} */,'
    content = re.sub(group_pattern, group_replacement, content)
    
    # Добавляем в Sources
    sources_pattern = r'(7C452D342E1AE37700A0C1B3 /\* Akt\.swift in Sources \*/,)'
    sources_replacement = f'\\1\n\t\t\t\t{build_file_id} /* {filename} in Sources */,'
    content = re.sub(sources_pattern, sources_replacement, content)
    
    # Записываем обратно
    with open(project_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Файл {filename} добавлен в проект с ID {file_ref_id}")

if __name__ == "__main__":
    project_path = "Gazprom.xcodeproj/project.pbxproj"
    file_path = "Gazprom/Models/VersionManager.swift"
    
    if os.path.exists(project_path) and os.path.exists(file_path):
        add_file_to_project(project_path, file_path)
        print("VersionManager.swift успешно добавлен в проект!")
    else:
        print("Файлы не найдены!")
