# MangoCommandParser - Local Pattern Handling

## Overview
`MangoCommandParser` (in `MangoCommand.swift`) handles voice command parsing **locally** without LLM calls. It runs first in the pipeline, and only falls back to LLM if no patterns match.

## Location
- **File**: `MangoCommand.swift`
- **Class**: `MangoCommandParser` (singleton via `MangoCommandParser.shared`)
- **Entry Point**: `func parse(_ text: String) -> MangoCommand`

## Command Types Returned

```swift
enum MangoCommand {
    case recommenderSearch(recommender: String, movie: String, raw: String)
    case movieSearch(query: String, raw: String)
    case createWatchlist(listName: String, raw: String)
    case unknown(raw: String)  // Falls back to LLM
}
```

---

## Pattern 1: Create Watchlist (Handled FIRST, before other patterns)

**Priority**: Checked first (line 59)

**Patterns Supported** (case-insensitive):
- `"create a new list called X"`
- `"create a new watchlist called X"`
- `"create a list called X"`
- `"make a new list called X"`
- `"make a list called X"`
- `"new list called X"`
- `"create a new list named X"`
- `"create a list named X"`
- `"make a new list named X"`
- `"make a list named X"`
- `"new list named X"`

**Extraction Logic**:
- Extracts everything after the pattern phrase
- Trims whitespace
- Removes trailing punctuation (`.`, `,`, `!`, `?`)
- Returns non-empty name, or `nil` if empty

**Returns**: `.createWatchlist(listName: String, raw: String)`

**Note**: This command is handled completely locally in `VoiceIntentRouter.handleCreateWatchlistCommand()` - **no LLM fallback**.

---

## Pattern 2: Recommender Search (Regex-based)

**Patterns Supported** (case-insensitive regex):
1. `"<name> recommends <movie>"`
2. `"<name> suggested <movie>"`
3. `"<name> said to watch <movie>"`
4. `"<name> likes <movie>"`
5. `"<name> liked <movie>"`

**Regex Details**:
- Uses `NSRegularExpression` with `.caseInsensitive` option
- Pattern: `^(.+?)\s+<verb>\s+(.+)$`
- Captures: Group 1 = recommender, Group 2 = movie
- Non-greedy matching (`.+?`) to handle multi-word recommenders

**Examples**:
- `"Keo recommends Arrival"` → recommender: "Keo", movie: "Arrival"
- `"The New York Times recommends The Godfather"` → recommender: "The New York Times", movie: "The Godfather"
- `"Sally suggested Parasite"` → recommender: "Sally", movie: "Parasite"

**Normalization**:
- Recommender names are normalized via `RecommenderNormalizer.normalize()` (e.g., "Kyo" → "Keo", "hyatt" → "Hayat")

**Returns**: `.recommenderSearch(recommender: String, movie: String, raw: String)`

---

## Pattern 3: Simple Movie Search (Fallback)

**Patterns Supported**:
- Any text containing `"add"` (case-insensitive) → extracts everything after "add"
- If no recommender pattern matched, extracts movie title from "add" pattern

**Cleanup Logic** (applied to movie title):
- Removes `"the movie"` prefix (case-insensitive)
- Removes `"to my watchlist"` suffix (case-insensitive)
- Trims whitespace

**Returns**: `.movieSearch(query: String, raw: String)`

---

## Pattern 4: Unknown (LLM Fallback)

**When**: No patterns match

**Returns**: `.unknown(raw: String)`

**Next Step**: `VoiceIntentRouter` sends to LLM (`OpenAIClient.classifyUtterance()`) for fallback parsing.

---

## Additional Local Commands (Handled in VoiceIntentRouter)

These are handled **after** `MangoCommandParser.parse()` but **before** LLM fallback:

### Pattern 5: "Add this movie to <ListName>" (Context-aware)
- **Location**: `VoiceIntentRouter.handleAddThisMovieToListCommand()`
- **Context Required**: `currentMovieId` must be set (Mango invoked from MoviePageView)
- **Patterns**: `"add this movie to X"`, `"add this to X"`, `"put this movie in X"`, etc.
- **Returns**: `true` if handled, `false` otherwise

### Pattern 6: "Sort this list by X" (Context-aware)
- **Location**: `VoiceIntentRouter.handleSortListCommand()`
- **Context Required**: `currentListContext` must be set (Mango invoked from WatchlistView)
- **Patterns**: `"sort this list by year"`, `"sort by genre"`, `"sort by title"`, etc.
- **Returns**: `true` if handled, `false` otherwise

---

## Processing Order (in VoiceIntentRouter)

1. **MangoCommandParser.parse()** - Local pattern matching
2. **Create Watchlist** - If `.createWatchlist`, handle locally and return (no LLM)
3. **Add This Movie** - If context exists, try local handler
4. **Sort List** - If context exists, try local handler
5. **LLM Fallback** - If command is `.unknown`, send to OpenAI

---

## Key Features

### Recommender Normalization
- All recommender names go through `RecommenderNormalizer.normalize()`
- Handles common speech-to-text mishearings:
  - "Kia", "Kyo", "kio" → "Keo"
  - "hyatt", "hi yat" → "Hayat"
  - "wsj" → "The Wall Street Journal"
  - "nyt" → "The New York Times"

### Movie Title Cleanup
- Removes filler words: "the movie", "to my watchlist"
- Trims whitespace
- Handles multi-word movie titles

### Case Insensitivity
- All pattern matching is case-insensitive
- Uses `.caseInsensitive` option in regex and string matching

---

## Examples

| Input | Command Type | Extracted Data |
|-------|-------------|----------------|
| `"create a new list called Comfort Movies"` | `.createWatchlist` | listName: "Comfort Movies" |
| `"Keo recommends Arrival"` | `.recommenderSearch` | recommender: "Keo", movie: "Arrival" |
| `"Kyo recommends The Sound of Music"` | `.recommenderSearch` | recommender: "Keo" (normalized), movie: "The Sound of Music" |
| `"add Parasite to my watchlist"` | `.movieSearch` | query: "Parasite" |
| `"The Devil Wears Prada"` | `.unknown` → LLM fallback | Sent to OpenAI |

---

## Notes for Implementation

- **Order matters**: Create watchlist is checked first
- **Regex is greedy**: Uses non-greedy `.+?` to handle multi-word recommenders
- **Normalization happens**: Recommender names are always normalized
- **Fallback chain**: Local parser → Context handlers → LLM → Movie search
- **No LLM for known patterns**: If local parser succeeds, no LLM call is made

