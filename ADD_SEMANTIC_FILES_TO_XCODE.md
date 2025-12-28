# Adding Semantic Search Files to Xcode Project

## Quick Steps

1. **Open Xcode** and your TastyMangoes project

2. **Right-click on your project** in the Project Navigator (left sidebar)
   - Or right-click on the folder where you want the files

3. **Select "Add Files to TastyMangoes..."**

4. **Navigate to** `/Users/timrobinson/Developer/TastyMangoes/`

5. **Select these 6 files** (hold Cmd to select multiple):
   - `SemanticSearchModels.swift`
   - `SemanticSearchService.swift`
   - `MangoVoiceManager.swift`
   - `SemanticSearchViewModel.swift`
   - `SemanticMovieCard.swift`
   - `RefinementChipsView.swift`

6. **Important:** Make sure these checkboxes are selected:
   - ✅ "Copy items if needed" (uncheck this - files are already in the right place)
   - ✅ "Add to targets: TastyMangoes" (check this!)

7. **Click "Add"**

## Verify

After adding, you should see all 7 semantic search files in your Project Navigator:
- ✅ SemanticSearchModels.swift
- ✅ SemanticSearchService.swift
- ✅ MangoVoiceManager.swift
- ✅ SemanticSearchViewModel.swift
- ✅ SemanticMovieCard.swift
- ✅ RefinementChipsView.swift
- ✅ SemanticSearchView.swift (already added)

## Build

After adding all files, try building:
- **Cmd+B** to build
- Should compile without errors now!

