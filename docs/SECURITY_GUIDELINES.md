# SAP Annotation Builder - Security Guidelines

## Версия документа: 1.0.0
## Дата: 2024

---

## 🔐 Обзор безопасности

Этот документ описывает меры безопасности, реализованные в SAP Annotation Builder, а также рекомендации по дополнительной защите при развертывании в production-среде.

---

## ✅ Реализованные функции безопасности

### 1. **Защита от Directory Traversal**

**Угроза**: Злоумышленник может попытаться получить доступ к файлам за пределами веб-директории используя пути типа `../../../etc/passwd`.

**Реализация**:
```powershell
function Resolve-SafeFilePath {
    param(
        [string]$BasePath,
        [string]$RequestedPath
    )
    
    # Нормализация путей
    $normalizedBase = [System.IO.Path]::GetFullPath($BasePath)
    $normalizedRequested = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($BasePath, $RequestedPath)
    )
    
    # Проверка что итоговый путь начинается с базового
    if (-not $normalizedRequested.StartsWith($normalizedBase, 
            [StringComparison]::OrdinalIgnoreCase)) {
        Write-ServerLog "Directory traversal attempt blocked: $RequestedPath" -Level "Warning"
        return $null
    }
    
    return $normalizedRequested
}
```

**Статус**: ✅ Реализовано и протестировано

---

### 2. **Ограничение размера файлов**

**Угроза**: DoS-атака через загрузку/чтение очень больших файлов.

**Реализация**:
```powershell
$Configuration.Security.MaxFileSizeBytes = 52428800  # 50MB

function Send-Response {
    param(
        [System.Net.HttpListenerContext]$Context,
        [byte[]]$Content
    )
    
    if ($Content.Length -gt $Configuration.Security.MaxFileSizeBytes) {
        Write-ServerLog "File size limit exceeded: $($Content.Length) bytes" -Level "Warning"
        $Context.Response.StatusCode = 413  # Payload Too Large
        return
    }
    
    # ... отправка контента
}
```

**Статус**: ✅ Реализовано

---

### 3. **CORS (Cross-Origin Resource Sharing)**

**Угроза**: CSRF-атаки и несанкционированный доступ из других доменов.

**Реализация**:
```powershell
$Configuration.Security = @{
    EnableCors = $false  # По умолчанию отключено
    AllowedOrigins = @("*")  # При включении - настроить явно
}

function Add-CorsHeaders {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$Origin
    )
    
    if (-not $Configuration.Security.EnableCors) {
        return
    }
    
    $allowedOrigins = $Configuration.Security.AllowedOrigins
    
    if ($allowedOrigins -contains "*" -or $allowedOrigins -contains $Origin) {
        $Response.Headers.Add("Access-Control-Allow-Origin", $Origin)
        $Response.Headers.Add("Access-Control-Allow-Methods", "GET, OPTIONS")
        $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
    }
}
```

**Статус**: ✅ Реализовано

**Рекомендация для Production**:
```json
{
  "security": {
    "enableCors": true,
    "allowedOrigins": [
      "https://your-domain.com",
      "https://app.your-domain.com"
    ]
  }
}
```

---

### 4. **Безопасное логирование**

**Угроза**: Утечка чувствительной информации через логи.

**Реализация**:
```powershell
function Write-ServerLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    # Очистка потенциально чувствительных данных
    $sanitizedMessage = $Message -replace '(password|secret|key)=\S+', '$1=[REDACTED]'
    
    # Добавление меток времени и уровня
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[${timestamp}] [${Level}] ${sanitizedMessage}"
    
    # Запись в файл
    Add-Content -Path $Configuration.Logging.LogFilePath -Value $logEntry
}
```

**Статус**: ⚠️ Частично реализовано (требуется улучшение)

---

### 5. **ETag для защиты от кэш-атак**

**Угроза**: Poisoning кэша через манипуляцию заголовками.

**Реализация**:
```powershell
function Get-ETag {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    
    $fileInfo = Get-Item $FilePath
    # Используем хэш содержимого + размер + время изменения
    $hash = [System.IO.Hashing.Crc32]::HashToHexString(
        [System.IO.File]::ReadAllBytes($FilePath)
    )
    
    return "`"$($fileInfo.LastWriteTimeUtc.Ticks)-$hash`""
}
```

**Статус**: ✅ Реализовано

---

## ⚠️ Известные ограничения

### 1. **Отсутствие HTTPS поддержки**

**Статус**: ❌ Не реализовано
**Риск**: Перехват данных в transit (MITM-атаки)
**План**: Реализовать в версии 2.2.0

**Временное решение**:
- Разворачивать за reverse proxy (nginx, Apache, IIS)
- Использовать только в доверенных сетях

---

### 2. **Отсутствие аутентификации**

**Статус**: ❌ Не реализовано
**Риск**: Несанкционированный доступ к серверу
**План**: Реализовать Basic Auth или Token-based auth в версии 2.3.0

**Временное решение**:
- Ограничить доступ на уровне сети (firewall)
- Использовать VPN для доступа

---

### 3. **Отсутствие rate limiting**

**Статус**: ❌ Не реализовано
**Риск**: DoS-атаки через большое количество запросов
**План**: Реализовать в версии 2.2.0

**Временное решение**:
- Настроить rate limiting на уровне reverse proxy
- Использовать фаервол для ограничения соединений

---

### 4. **Синхронное логирование**

**Статус**: ⚠️ Реализовано неоптимально
**Риск**: Возможна потеря логов при крахе процесса
**План**: Асинхронное логирование в версии 2.2.0

---

## 🔒 Рекомендации по безопасному развертыванию

### Для Development среды

```json
{
  "security": {
    "maxFileSizeBytes": 52428800,
    "enableCors": false,
    "allowedOrigins": ["*"]
  },
  "logging": {
    "level": "Debug",
    "enableFileLogging": true
  }
}
```

**Дополнительные меры**:
- ✅ Запускать только на localhost
- ✅ Использовать фаервол для блокировки внешних подключений
- ✅ Регулярно очищать логи

---

### Для Production среды

```json
{
  "security": {
    "maxFileSizeBytes": 10485760,
    "enableCors": true,
    "allowedOrigins": [
      "https://your-domain.com"
    ],
    "enableHttps": true,
    "certificateThumbprint": "YOUR_CERT_THUMBPRINT"
  },
  "logging": {
    "level": "Warning",
    "enableFileLogging": true,
    "logFilePath": "/var/log/sap-annotation-builder/server.log",
    "maxLogFileSizeBytes": 52428800,
    "maxLogFiles": 10
  },
  "performance": {
    "requestTimeoutSeconds": 30,
    "maxConcurrentConnections": 100
  }
}
```

**Обязательные меры**:
1. **Reverse Proxy**: Развернуть за nginx/Apache/IIS
2. **HTTPS**: Терминировать SSL на reverse proxy
3. **Firewall**: Ограничить доступ только с доверенных IP
4. **Monitoring**: Настроить мониторинг логов на предмет атак
5. **Updates**: Регулярно обновлять PowerShell и .NET runtime
6. **Backup**: Регулярное резервное копирование конфигурации и логов

---

## 🛡️ Checklist безопасности

### Перед развертыванием

- [ ] Изменены все пароли по умолчанию
- [ ] CORS настроен явно для конкретных доменов
- [ ] Логирование включено с уровнем Warning или выше
- [ ] Размер логов ограничен (rotation настроен)
- [ ] Фаервол настроен для ограничения доступа
- [ ] Сертификаты HTTPS установлены (если применимо)
- [ ] Rate limiting настроен (на уровне proxy или OS)

### После развертывания

- [ ] Проведен security scan уязвимостей
- [ ] Настроен мониторинг подозрительной активности
- [ ] Протестирована процедура восстановления после инцидента
- [ ] Документация по безопасности доступна команде
- [ ] Назначен ответственный за security updates

### Регулярные проверки (ежемесячно)

- [ ] Анализ логов на предмет атак
- [ ] Проверка актуальности зависимостей
- [ ] Тестирование backup/restore процедуры
- [ ] Обновление документации по безопасности

---

## 🚨 Response Plan при инцидентах

### Типы инцидентов

#### 1. Подозрительная активность в логах
**Симптомы**: Множественные попытки directory traversal, необычные User-Agent
**Действия**:
1. Заблокировать IP на уровне фаервола
2. Сохранить логи для анализа
3. Уведомить security team
4. Провести forensic анализ

#### 2. DoS-атака
**Симптомы**: Высокая нагрузка, медленные ответы, таймауты
**Действия**:
1. Включить rate limiting (если доступен)
2. Заблокировать атакующие IP диапазоны
3. Масштабировать инфраструктуру (если возможно)
4. Обратиться к ISP/DDoS mitigation service

#### 3. Утечка данных
**Симптомы**: Необычный outbound трафик, жалобы пользователей
**Действия**:
1. Немедленно остановить сервер
2. Сохранить дампы памяти и логи
3. Начать расследование инцидента
4. Уведомить затронутых пользователей (по требованию GDPR)

---

## 📚 Дополнительные ресурсы

### Стандарты и фреймворки
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Benchmarks for Windows](https://www.cisecurity.org/benchmark/microsoft_windows)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

### Инструменты
- [PowerShell Script Analyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- [Nmap](https://nmap.org/) - Сканирование портов
- [Wireshark](https://www.wireshark.org/) - Анализ трафика

### Обучение
- [Microsoft Security Best Practices](https://docs.microsoft.com/en-us/security/)
- [SANS Secure Coding Guidelines](https://www.sans.org/top25-software-errors/)

---

## 📞 Контакты

По вопросам безопасности обращайтесь:
- Email: security@your-domain.com
- Bug Bounty Program: https://your-domain.com/security

---

*Документ является частью проекта SAP Annotation Builder v2.1.0*

**Последнее обновление**: 2024
**Следующий пересмотр**: Q1 2025
