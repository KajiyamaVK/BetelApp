# 5. Data Layer (SQLite & JSON)

This document outlines the data structure for the BetelSAS application, covering both the local JSON data format used for seed/static content and the SQLite schema used for local persistence.

## 1. JSON Data Format (`assets/data/lessons.json`)

The application consumes a JSON file located at `assets/data/lessons.json` to load initial lesson data.

### Root Structure

An array of Lesson objects.

```json
[
  {
    "id": 1,
    "title": "String",
    "category": "String",
    "imageUrl": "String (asset path)",
    "content": "String",
    "scriptureReference": "String",
    "song": { ... },
    "flashcards": [ ... ]
  }
]
```

### Lesson Object

| Field | Type | Description |
| --- | --- | --- |
| `id` | Integer | Unique identifier for the lesson. |
| `title` | String | Title of the lesson. |
| `category` | String | Category (e.g., "Teologia Sistemática"). |
| `imageUrl` | String | Path to the lesson image asset. |
| `content` | String | Main text content of the lesson. |
| `scriptureReference` | String | Bible reference (e.g., "Gênesis 1:1"). |
| `song` | Object | Nested Song object (optional/nullable). |
| `flashcards` | Array | List of Flashcard objects. |

### Song Object

| Field | Type | Description |
| --- | --- | --- |
| `id` | String | Unique identifier for the song. |
| `title` | String | Song title. |
| `artist` | String | Artist name. |
| `audioUrl` | String | Path to the audio asset. |
| `durationIds` | Integer | Duration in seconds. |

### Flashcard Object

| Field | Type | Description |
| --- | --- | --- |
| `id` | String | Unique identifier for the flashcard. |
| `question` | String | The question text. |
| `answer` | String | The answer text. |

---

## 2. User Progress Strategy (Manual Marking)

To avoid complex state management and SRS algorithms for the MVP, the app will use a simple "Understood / Not Understood" manual marking system.

### Persistence (Local Only)

For the MVP, user progress will be stored locally (e.g., SharedPreferences or simple JSON file write), tracking:

- **Lessons Completed**: List of lesson IDs.
- **Flashcards Mastered**: List of flashcard IDs marked as "Understood".
- **Favorites**: List of IDs for favorite lessons/songs.

No relational database (SQLite) is required at this stage.
