# 4. Technical Details

## Technical Decisions & Constraints

### Architecture & Data

- **Authentication**: **None**. Users bypass login and land directly on the Home screen.
- **Data Source**: Static JSON files bundled in `assets/` (Lessons, Music metadata). No remote API calls initially.
- **Media**: Audio and image assets are stored locally within the app bundle for full offline support.
- **Persistence**: **SharedPreferences** (or similar lightweight storage) for storing:
  - User progress (completed lessons).
  - Favorites (Lessons/Music).
  - Flashcard mastery status.

### Logic & Algorithms

- **Flashcards**: Manual "Understood/Not Understood" marking by the user. No complex algorithm.
- **State Management**: Local-only state. No cloud sync required for current phase.

### UI/UX Decisions

- **Empty States**: Developer's discretion to design clean, beautiful placeholders for empty lists (e.g., "No Favorites yet").
- **Loading States**: Use modern, fluid animations (skeletons/shimmers) during any data parsing or loading phases to maintain a premium feel.
