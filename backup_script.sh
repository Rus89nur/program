#!/bin/bash

# Скрипт автоматического резервного копирования для проекта Gazprom
# Автор: AI Assistant
# Дата создания: $(date)

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
PROJECT_DIR="/Users/ruslan/Desktop/Gazprom 9"
BACKUP_DIR="/Users/ruslan/Desktop/Backups/Gazprom"
GIT_REPO_URL="" # Будет настроен позже
MAX_BACKUPS=10

# Создаем директорию для бэкапов если её нет
mkdir -p "$BACKUP_DIR"

# Функция логирования
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Функция создания резервной копии
create_backup() {
    local backup_name="Gazprom_backup_$(date '+%Y%m%d_%H%M%S')"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log "Создание резервной копии: $backup_name"
    
    # Создаем копию проекта
    if cp -R "$PROJECT_DIR" "$backup_path"; then
        success "Резервная копия создана: $backup_path"
        
        # Создаем архив для экономии места
        cd "$BACKUP_DIR"
        if tar -czf "${backup_name}.tar.gz" "$backup_name" && rm -rf "$backup_name"; then
            success "Архив создан: ${backup_name}.tar.gz"
        else
            error "Ошибка создания архива"
            return 1
        fi
        
        # Очищаем старые бэкапы
        cleanup_old_backups
        
        return 0
    else
        error "Ошибка создания резервной копии"
        return 1
    fi
}

# Функция очистки старых бэкапов
cleanup_old_backups() {
    log "Очистка старых резервных копий (максимум $MAX_BACKUPS)"
    
    cd "$BACKUP_DIR"
    # Удаляем старые архивы, оставляя только последние MAX_BACKUPS
    ls -t Gazprom_backup_*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -f
    
    success "Старые резервные копии очищены"
}

# Функция Git commit
git_commit() {
    cd "$PROJECT_DIR"
    
    # Добавляем все изменения
    git add .
    
    # Проверяем есть ли изменения для коммита
    if git diff --staged --quiet; then
        warning "Нет изменений для коммита"
        return 0
    fi
    
    # Создаем коммит
    local commit_message="Автоматический коммит $(date '+%Y-%m-%d %H:%M:%S')"
    if git commit -m "$commit_message"; then
        success "Git коммит создан: $commit_message"
        return 0
    else
        error "Ошибка создания Git коммита"
        return 1
    fi
}

# Функция синхронизации с удаленным репозиторием
git_sync() {
    if [ -z "$GIT_REPO_URL" ]; then
        warning "URL удаленного репозитория не настроен. Пропускаем синхронизацию."
        return 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Проверяем есть ли удаленный репозиторий
    if ! git remote get-url origin >/dev/null 2>&1; then
        log "Добавление удаленного репозитория: $GIT_REPO_URL"
        git remote add origin "$GIT_REPO_URL"
    fi
    
    # Отправляем изменения
    if git push origin main; then
        success "Изменения отправлены в удаленный репозиторий"
    else
        error "Ошибка отправки в удаленный репозиторий"
        return 1
    fi
}

# Функция восстановления из резервной копии
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        error "Не указан файл резервной копии для восстановления"
        echo "Доступные резервные копии:"
        ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "Резервные копии не найдены"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        error "Файл резервной копии не найден: $backup_file"
        return 1
    fi
    
    log "Восстановление из резервной копии: $backup_file"
    
    # Создаем резервную копию текущего состояния
    create_backup
    
    # Очищаем текущую директорию (кроме .git)
    find "$PROJECT_DIR" -maxdepth 1 -not -name '.git' -not -name '.' -exec rm -rf {} +
    
    # Распаковываем резервную копию
    if tar -xzf "$backup_file" -C "$(dirname "$PROJECT_DIR")" && mv "$(dirname "$PROJECT_DIR")/Gazprom 9"/* "$PROJECT_DIR"/; then
        success "Восстановление завершено успешно"
    else
        error "Ошибка восстановления из резервной копии"
        return 1
    fi
}

# Функция показа справки
show_help() {
    echo "Скрипт резервного копирования для проекта Gazprom"
    echo ""
    echo "Использование: $0 [команда]"
    echo ""
    echo "Команды:"
    echo "  backup     - Создать резервную копию"
    echo "  commit     - Создать Git коммит"
    echo "  sync       - Синхронизировать с удаленным репозиторием"
    echo "  full       - Полный бэкап (коммит + резервная копия + синхронизация)"
    echo "  restore    - Восстановить из резервной копии"
    echo "  list       - Показать доступные резервные копии"
    echo "  help       - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 backup"
    echo "  $0 full"
    echo "  $0 restore /path/to/backup.tar.gz"
}

# Функция показа списка резервных копий
list_backups() {
    log "Доступные резервные копии:"
    ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "Резервные копии не найдены"
}

# Основная логика
case "$1" in
    "backup")
        create_backup
        ;;
    "commit")
        git_commit
        ;;
    "sync")
        git_sync
        ;;
    "full")
        log "Запуск полного резервного копирования"
        git_commit && create_backup && git_sync
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "list")
        list_backups
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        error "Неизвестная команда: $1"
        show_help
        exit 1
        ;;
esac
