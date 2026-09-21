# SAP Annotation Builder - Contributing Guide

## Версия документа: 1.0.0
## Дата: 2024

---

## 👋 Добро пожаловать!

Спасибо за интерес к проекту **SAP Annotation Builder**! Этот документ поможет вам начать вносить свой вклад в развитие проекта.

---

## 📋 Содержание

1. [С чего начать](#с-чего-начать)
2. [Как сообщить об ошибке](#как-сообщить-об-ошибке)
3. [Как предложить улучшение](#как-предложить-улучшение)
4. [Процесс внесения изменений](#процесс-внесения-изменений)
5. [Стандарты кода](#стандарты-кода)
6. [Тестирование](#тестирование)
7. [Документация](#документация)
8. [Code Review](#code-review)
9. [Сообщество](#сообщество)

---

## 🚀 С чего начать

### 1. Fork репозитория

```bash
# Нажмите кнопку "Fork" на GitHub
# Или используйте CLI:
gh repo fork <original-repo-url>
```

### 2. Клонируйте ваш fork

```bash
git clone https://github.com/YOUR_USERNAME/SAPAnnotationBuilder.git
cd SAPAnnotationBuilder
```

### 3. Настройте remote для sync с оригиналом

```bash
git remote add upstream https://github.com/ORIGINAL_OWNER/SAPAnnotationBuilder.git
git fetch upstream
```

### 4. Создайте ветку для вашей работы

```bash
git checkout -b feature/your-feature-name
# или для исправления бага:
git checkout -b fix/issue-123-fix-bug-description
```

---

## 🐛 Как сообщить об ошибке

### Перед созданием issue

1. ✅ Проверьте существующие issues (возможно, ошибка уже известна)
2. ✅ Обновитесь до последней версии
3. ✅ Попробуйте воспроизвести ошибку на чистой системе
4. ✅ Соберите информацию для отчета

### Шаблон отчета об ошибке

```markdown
**Описание ошибки**
Краткое и понятное описание проблемы.

**Воспроизведение**
Шаги для воспроизведения:
1. Запустить команду '...'
2. Открыть файл '...'
3. Увидеть ошибку

**Ожидаемое поведение**
Что должно было произойти.

**Фактическое поведение**
Что произошло вместо ожидаемого.

**Окружение**
- OS: [Windows 10 / macOS / Linux]
- PowerShell версия: [pwsh -v]
- Версия модуля: [Get-Module SAPAnnotationBuilder]

**Логи**
```
Приложите соответствующие логи из файла server.log
```

**Скриншоты**
Если применимо, добавьте скриншоты.

**Дополнительный контекст**
Любая дополнительная информация.
```

### Создать issue

Перейдите на вкладку **Issues** → **New Issue** → Выберите шаблон **Bug Report**

---

## 💡 Как предложить улучшение

### Типы улучшений

- ✨ **Новые функции** (новые endpoints, хендлеры, утилиты)
- ⚡ **Оптимизация производительности**
- 🔒 **Улучшения безопасности**
- 📚 **Улучшения документации**
- 🧪 **Улучшения тестирования**
- 🎨 **Рефакторинг кода**

### Шаблон предложения улучшения

```markdown
**Тип улучшения**
[Функция / Производительность / Безопасность / Документация / Другое]

**Описание**
Подробное описание предлагаемого улучшения.

**Мотивация**
Почему это улучшение важно? Какую проблему решает?

**Предлагаемое решение**
Как вы предлагаете реализовать это улучшение?

**Альтернативы**
Какие альтернативные решения вы рассмотрели?

**Дополнительный контекст**
Примеры использования, референсы, связанные issues.
```

---

## 🔧 Процесс внесения изменений

### Шаг 1: Обсуждение (для крупных изменений)

Для значительных изменений сначала создайте **Feature Request** issue и обсудите с мейнтейнерами.

### Шаг 2: Реализация

```bash
# Sync с upstream
git fetch upstream
git rebase upstream/main

# Внесите изменения в коде
# Добавьте тесты
# Обновите документацию
```

### Шаг 3: Тестирование

```powershell
# Запустите все тесты
Invoke-Pester -Path ./tests/

# Проверьте стиль кода
Invoke-ScriptAnalyzer -Path ./modules/

# Убедитесь что нет предупреждений
Import-Module ./modules/SAPAnnotationBuilder.psm1 -Force
```

### Шаг 4: Коммит

```bash
# Следуйте Conventional Commits
git add .
git commit -m "feat: add new health check endpoint"
# или
git commit -m "fix: resolve directory traversal vulnerability"
# или
git commit -m "docs: update SECURITY_GUIDELINES.md"
```

### Шаг 5: Push и Pull Request

```bash
git push origin feature/your-feature-name

# Создайте PR через GitHub UI или CLI
gh pr create --title "feat: add new health check endpoint" --body "Description of changes"
```

---

## 📝 Стандарты кода

### PowerShell Best Practices

#### 1. Именование функций

```powershell
# ✅ Правильно: Глагол-Существительное в PascalCase
function Get-Configuration { }
function Invoke-RequestHandler { }
function Test-WebDirectory { }

# ❌ Неправильно:
function getconfig { }
function HandleRequest { }
function test_dir { }
```

#### 2. Comment-based помощь

```powershell
function Get-MimeType {
    <#
    .SYNOPSIS
        Gets the MIME type for a file based on its extension
    
    .DESCRIPTION
        Returns the appropriate MIME type for static file serving.
        Supports common web formats (HTML, CSS, JS, images, etc.)
    
    .PARAMETER FilePath
        The path to the file to determine MIME type for
    
    .OUTPUTS
        System.String - The MIME type
    
    .EXAMPLE
        Get-MimeType -FilePath "style.css"
        Returns: text/css
    
    .NOTES
        Author: Your Name
        Date: 2024-01-01
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    # Implementation...
}
```

#### 3. Обработка ошибок

```powershell
# ✅ Правильно: Try-Catch с конкретными исключениями
try {
    $content = Get-Content -Path $filePath -Raw -ErrorAction Stop
} catch [System.IO.FileNotFoundException] {
    Write-ServerLog "File not found: $filePath" -Level "Warning"
    return $null
} catch [System.UnauthorizedAccessException] {
    Write-ServerLog "Access denied: $filePath" -Level "Error"
    throw
}

# ❌ Неправильно: Пустой catch или игнорирование ошибок
try {
    Do-Something
} catch {
    # Пусто - ошибка теряется
}
```

#### 4. Использование параметров

```powershell
# ✅ Правильно: Явные параметры с типами и валидацией
function Send-Response {
    param(
        [Parameter(Mandatory=$true)]
        [System.Net.HttpListenerContext]$Context,
        
        [Parameter(Mandatory=$true)]
        [byte[]]$Content,
        
        [int]$StatusCode = 200,
        
        [string]$ContentType = "text/html",
        
        [switch]$EnableCaching
    )
    
    # Implementation...
}

# ❌ Неправильно: Без типов, без валидации
function Send-Response($ctx, $content, $code, $type, $cache) {
    # Implementation...
}
```

#### 5. Логирование

```powershell
# ✅ Правильно: Соответствующие уровни логирования
Write-ServerLog "Server started on port $port" -Level "Info"
Write-ServerLog "Deprecated API called" -Level "Warning"
Write-ServerLog "Failed to open file: $error" -Level "Error"

# ❌ Неправильно: Write-Host или Write-Output для логов
Write-Host "Server started"  # Не попадает в логи
Write-Output "Error occurred"  # Смешивается с выводом
```

### Стиль кода

```powershell
# Отступы: 4 пробела (не табы)
function Example {
    param($Param1)
    
    if ($condition) {
        Do-Something
    }
}

# Пустые строки между функциями
function First-Function { }

function Second-Function { }

# Максимальная длина строки: 120 символов
$veryLongVariableName = "This is a very long string that should be broken into multiple lines if it exceeds..."

# Группировка импортов
# 1. Microsoft modules
# 2. Third-party modules
# 3. Local scripts
```

---

## 🧪 Тестирование

### Требования к тестам

1. ✅ **Все новые функции должны иметь тесты**
2. ✅ **Существующие тесты не должны ломаться**
3. ✅ **Тесты должны быть независимыми**
4. ✅ **Тесты должны быть быстрыми (<5 сек каждый)**

### Структура тестов

```powershell
Describe "Function-Name" {
    Context "Normal operation" {
        It "Should do expected behavior" {
            # Arrange
            $input = "test"
            
            # Act
            $result = Function-Name -Input $input
            
            # Assert
            $result | Should -Be "expected"
        }
    }
    
    Context "Edge cases" {
        It "Should handle null input" {
            # Test null handling
        }
        
        It "Should handle empty input" {
            # Test empty string handling
        }
    }
    
    Context "Error conditions" {
        It "Should throw on invalid input" {
            { Function-Name -Input $invalid } | Should -Throw
        }
    }
}
```

### Запуск тестов

```powershell
# Все тесты
Invoke-Pester -Path ./tests/

# Конкретный файл
Invoke-Pester -Path ./tests/SAPAnnotationBuilder.Tests.ps1

# Конкретный тест по тегу
Invoke-Pester -Path ./tests/ -Tag "Security"

# С покрытием кода (требуется Pester 5+)
Invoke-Pester -Path ./tests/ -CodeCoverage ./modules/*.psm1
```

### Минимальное покрытие

- **Новый код**: ≥80% покрытие тестами
- **Критические функции**: 100% покрытие (безопасность, обработка файлов)
- **Существующий код**: поддерживать текущий уровень

---

## 📚 Документация

### Что документировать

1. ✅ **Все публичные функции** (comment-based help)
2. ✅ **Изменения в поведении** (CHANGELOG.md)
3. ✅ **Новые функции** (README.md, специализированные гайды)
4. ✅ **Breaking changes** (миграционные гайды)

### Формат документации

```markdown
# Заголовок

Краткое введение (1-2 абзаца).

## Раздел

### Подраздел

- Списки для перечислений
- `inline code` для имен функций/параметров
- Блоки кода с указанием языка:

```powershell
# Пример кода
Get-Command -Module SAPAnnotationBuilder
```

**Жирный текст** для акцентов.
*Курсив* для терминов.

> Цитаты для важных замечаний.

| Таблицы | Для | Данных |
|---------|-----|--------|
| Ячейка  | Ячейка | Ячейка |

[Ссылки](url) на ресурсы.
```

### Обновление CHANGELOG.md

```markdown
## [2.2.0] - 2024-XX-XX

### Added
- New feature description (#issue-number)

### Changed
- Changed behavior description

### Fixed
- Bug fix description (#issue-number)

### Deprecated
- Feature being deprecated

### Removed
- Feature being removed

### Security
- Security improvement description
```

---

## 🔍 Code Review

### Чеклист для авторов PR

- [ ] Код следует стандартам проекта
- [ ] Все тесты проходят
- [ ] Добавлены тесты для нового кода
- [ ] Документация обновлена
- [ ] CHANGELOG.md обновлен (если применимо)
- [ ] Нет предупреждений от ScriptAnalyzer
- [ ] Коммиты следуют Conventional Commits

### Чеклист для ревьюверов

- [ ] Код решает заявленную проблему
- [ ] Нет очевидных багов
- [ ] Обработка ошибок реализована
- [ ] Логирование добавлено где нужно
- [ ] Тесты покрывают основные сценарии
- [ ] Документация актуальна
- [ ] Нет проблем с безопасностью

### Время ответа

- **Обычные PR**: 2-3 рабочих дня
- **Critical security fixes**: 24 часа
- **Documentation fixes**: 1-2 рабочих дня

---

## 🤝 Сообщество

### Кодекс поведения

Мы придерживаемся принципов **Open Source Code of Conduct**:

- 🤝 Будьте уважительны к другим участникам
- 💬 Конструктивная критика приветствуется
- 🌍 Приветствуются участники любого уровня
- 🚫 Нетерпимость к дискриминации и харассменту

### Как получить помощь

- 💬 **GitHub Discussions**: Общие вопросы
- 🐛 **GitHub Issues**: Баги и фичи
- 📧 **Email**: contrib@your-domain.com (для sensitive вопросов)

### Признание вклада

Все контрибьюторы упоминаются в:
- [CONTRIBUTORS.md](./CONTRIBUTORS.md)
- Release notes для соответствующей версии
- Благодарности в документации

---

## 📈 Карьера контрибьютора

### Уровни участия

1. **Новичок**: Первый PR (documentation fix, typo)
2. **Контрибьютор**: Несколько PR с кодом/тестами
3. **Активный контрибьютор**: Регулярные contributions
4. **Maintainer**: Право merge PR, управление релизами

### Как стать мейнтейнером

- 6+ месяцев активного участия
- 10+ merged PR
- Глубокое понимание кодовой базы
- Recommendation от текущих мейнтейнеров

---

## 📞 Контакты

- **Project Lead**: @username
- **Core Team**: @user1, @user2, @user3
- **Security Team**: security@your-domain.com

---

## 🙏 Спасибо!

Ваш вклад делает проект лучше! Мы ценим каждое улучшение, будь то исправление опечатки или крупная новая функция.

Happy coding! 🚀

---

*Документ является частью проекта SAP Annotation Builder v2.1.0*

**Последнее обновление**: 2024
**Лицензия**: [Указать лицензию проекта]
