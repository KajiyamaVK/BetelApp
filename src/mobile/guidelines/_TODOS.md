# Future Roadmap & TODOs

This document tracks planned features and architectural improvements that are out of scope for the current MVP but intended for future iterations.

## Backend & Data

- [ ] **SQLite Integration**: Migrate from local JSON/SharedPreferences to a relational SQLite database for robust local data persistence.
- [ ] **Spaced Repetition System (SRS)**: Implement an algorithm (e.g., SM-2 or Leitner) to automate flashcard review intervals based on user performance.
- [ ] **Cloud Sync**: Implement synchronization with a remote backend to save progress across devices.
- [ ] **Cloud Storage**: Implement a persistent cloud database (e.g., PostgreSQL, Firebase) to store user data securely and prevent loss if the device is reset.

## Authentication & User Management

- [ ] **Login System**: Implement secure user authentication (Email/Password, Social Login) to support cloud sync and multi-device usage.
- [ ] **User Profiles**: Allow multiple user profiles (e.g., parents and children) within a single account.

## Platforms & Tools

- [ ] **Web Platform**: Develop a web-based administration interface/CMS.
  - Enable content creators to add/edit lessons, songs, and flashcards via a rich text editor.
  - Export data to the JSON format used by the mobile app (or sync directly to backend).
