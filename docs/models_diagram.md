# Блок-схема моделей проекта

## Диаграмма связей моделей

```mermaid
erDiagram
    User ||--o{ ConstructionSite : "управляет"
    User ||--o{ ProjectSheet : "исполняет"
    User ||--o{ ProjectStage : "создает"
    User ||--o{ ProjectSheetNote : "создает"
    
    Status ||--o{ ProjectSheet : "имеет статус"
    Status ||--o{ ProjectStage : "имеет статус"
    
    ConstructionSite ||--o{ Project : "содержит"
    Project ||--o{ ProjectSheet : "содержит"
    Project ||--o{ ProjectStage : "имеет этапы"
    ProjectSheet ||--o{ ProjectSheetNote : "имеет заметки"
    
    User {
        int id PK
        string username
        string email
        datetime date_joined
    }
    
    Status {
        int id PK
        string name
        string color
        string status_type
        datetime created_at
    }
    
    ConstructionSite {
        int id PK
        string name
        text description
        int manager_id FK
        datetime created_at
        datetime updated_at
    }
    
    Project {
        int id PK
        string name
        text description
        string code
        string cipher
        int construction_site_id FK
        datetime created_at
        datetime updated_at
    }
    
    ProjectSheet {
        int id PK
        string name
        text description
        int project_id FK
        int status_id FK
        boolean is_completed
        datetime completed_at
        file file
        datetime created_at
        datetime updated_at
    }
    
    ProjectStage {
        int id PK
        int project_id FK
        int status_id FK
        datetime datetime
        int author_id FK
        text description
        file file
        datetime created_at
    }
    
    ProjectSheetNote {
        int id PK
        string name
        text note
        file file
        int author_id FK
        int project_sheet_id FK
        datetime created_at
        datetime updated_at
    }
```

## Описание моделей

### User (Пользователь)
- Стандартная модель Django
- Связи: управляет участками, исполняет листы, создает этапы и заметки

### Status (Статус)
- Типы: `sheet` (проектный лист), `stage` (этап проекта)
- Используется для отслеживания состояния листов и этапов

### ConstructionSite (Строительный участок)
- Содержит проекты
- Имеет менеджера (User)
- Вычисляемый процент выполнения (средний по проектам)

### Project (Проект)
- Принадлежит строительному участку
- Имеет код и шифр
- Вычисляемый процент выполнения (по завершенным листам)

### ProjectSheet (Проектный лист)
- Принадлежит проекту
- Имеет статус, исполнителей (ManyToMany с User)
- Может быть помечен как выполненный
- Автоматически устанавливает дату выполнения

### ProjectStage (Этап проекта)
- Принадлежит проекту
- Имеет дату-время и автора
- Может содержать файлы и описание

### ProjectSheetNote (Заметка проектного листа)
- Принадлежит проектному листу
- Имеет автора
- Может содержать файлы

