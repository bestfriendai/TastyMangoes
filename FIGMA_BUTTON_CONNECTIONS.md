//  FIGMA_BUTTON_CONNECTIONS.md
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 14:45 (America/Los_Angeles - Pacific Time)
//  Notes: Analysis of Figma prototype connections - button interactions and navigation flows extracted from single API call

# Figma Button Connection Analysis

## Summary

**Single API Call Successfully Extracted:**
- ✅ **897 total button interactions** found
- ✅ **860 unique buttons** identified
- ✅ **168 unique destinations** mapped
- ✅ **5 navigation types** identified

## Navigation Types Breakdown

| Type | Count | Description |
|------|-------|-------------|
| `CHANGE_TO` | 666 | Component state changes (e.g., button pressed state, card variants) |
| `NAVIGATE` | 111 | Navigation to different screens/views |
| `OVERLAY` | 56 | Bottom sheets, modals, overlays |
| `SCROLL_TO` | 25 | Scroll to sections within same screen |
| `SWAP` | 39 | Component swapping/variant changes |

## Key Findings

### 1. Button → Screen Navigation (`NAVIGATE`)
Examples:
- **Search Button** → Navigates to `Search` screen (ID: `5022:11537`)
- Multiple navigation buttons throughout the app

### 2. Button → Bottom Sheet (`OVERLAY`)
Examples:
- **Rate Button** → Opens `Bottom Sheed / Rate` (ID: `5022:13454`)
- **Menu Button** → Opens `Bottom Sheed / Menu` (ID: `5022:10487`)
- **Add to Watchlist Button** → Opens `Bottom Sheed / Watchlist` (ID: `5022:10792`)

### 3. Tab → Section Scroll (`SCROLL_TO`)
Examples:
- **Tab "Cast & Crew"** → Scrolls to section (ID: `5022:10104`)
- **Tab "Reviews"** → Scrolls to section (ID: `5022:10122`)
- **Tab "More to Watch"** → Scrolls to section (ID: `5022:10135`)
- **Tab "Movie Clips"** → Scrolls to section (ID: `5022:10164`)
- **Tab "Photos"** → Scrolls to section (ID: `5022:10172`)

### 4. Component State Changes (`CHANGE_TO`)
Examples:
- **Card / Platform** → Changes to variant `Property 1=4` (ID: `5022:13650`)
- **Card / Friends** → Changes to variant `Property 1=2` (ID: `5022:13644`)
- **Button / Mark as Watched** → Changes to `Active=True, Text=True` (ID: `5022:12259`)

## Implementation Strategy

### Can Wire Up Automatically:

1. **Navigation Buttons** (`NAVIGATE`)
   - Map button node IDs to SwiftUI view destinations
   - Use NavigationLink or programmatic navigation

2. **Bottom Sheets** (`OVERLAY`)
   - Map to `.sheet()` or `.fullScreenCover()` presentations
   - Match destination IDs to existing bottom sheet views

3. **Tab Scrolling** (`SCROLL_TO`)
   - Map to ScrollViewReader with scrollTo actions
   - Use section IDs for smooth scrolling

4. **State Changes** (`CHANGE_TO`)
   - Map to @State variables for component variants
   - Handle button pressed states, card selections, etc.

### Needs Clarification:

1. **Complex Business Logic**
   - API calls triggered by buttons
   - Data transformations
   - Validation rules

2. **Shared State**
   - State management between screens
   - Data persistence requirements

3. **Edge Cases**
   - Error handling
   - Loading states
   - Empty states

## File Reference

- **Figma File Key**: `r3LEbfkwRawRc9bvIFXkTA`
- **Selected Node**: `5021-39427` (contains 45 selected elements)
- **Prototype Start Node**: `5022:11934`
- **Full Analysis JSON**: `/tmp/figma_button_analysis.json`

## Next Steps

1. ✅ **DONE**: Single API call extracted all button connections
2. **TODO**: Map Figma node IDs to SwiftUI view identifiers
3. **TODO**: Implement navigation wiring based on `NAVIGATE` connections
4. **TODO**: Implement bottom sheet presentations based on `OVERLAY` connections
5. **TODO**: Implement scroll-to-section for `SCROLL_TO` connections
6. **TODO**: Handle component state changes for `CHANGE_TO` connections

## Rate Limit Status

- ✅ **Single API call successful**
- ✅ **No rate limiting encountered**
- ✅ **All data extracted in one request**
- ✅ **Ready for batched image requests** (when needed)

## Conclusion

**YES - We can wire up buttons automatically!** 

The single Figma API call successfully extracted:
- All button → destination mappings
- Navigation types and transitions
- Component hierarchies
- Prototype flow information

We can now automatically wire up:
- ✅ Navigation between screens
- ✅ Bottom sheet presentations
- ✅ Scroll-to-section functionality
- ✅ Component state changes

Only complex business logic and edge cases will need manual clarification.

