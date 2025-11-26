# Streaming Platform Icons Setup Guide

## Overview
This guide explains how to add official streaming service logos to replace the colored placeholder boxes.

## File Format
**Use PNG or PDF format:**
- **PNG**: Standard format, requires @2x and @3x variants for different screen densities
- **PDF (Vector)**: Recommended - single file scales to any size automatically
- **SVG**: Not natively supported by iOS - convert to PDF or PNG first

## Where to Get Icons

### Option 1: Official Brand Assets (Recommended)
Many streaming services provide official logos:
- **Netflix**: [Brand Assets](https://about.netflix.com/en/news/brand-assets)
- **Disney+**: [Brand Guidelines](https://www.disney.com/brand-guidelines/)
- **Prime Video**: [Amazon Brand Assets](https://advertising.amazon.com/resources/ad-policy/brand-guidelines)
- **Max**: [Warner Bros. Discovery Brand Assets](https://www.wbd.com/brand-assets/)
- **Hulu**: [Brand Guidelines](https://www.hulu.com/press)
- **Paramount+**: [ViacomCBS Brand Assets](https://www.viacomcbs.com/brand-assets)
- **Apple TV+**: [Apple Brand Resources](https://developer.apple.com/app-store/marketing/guidelines/)
- **Peacock**: [NBCUniversal Brand Assets](https://www.nbcuniversal.com/brand-assets)
- **Tubi**: [Tubi Brand Guidelines](https://www.tubi.tv/press)
- **Criterion**: [Criterion Collection Brand Assets](https://www.criterion.com/)

### Option 2: Wikimedia Commons
- Search for "[Service Name] logo" on [Wikimedia Commons](https://commons.wikimedia.org/)
- Many logos available in SVG format (convert to PDF for iOS)

### Option 3: Logo Aggregator Sites
- [Logojinni](https://logojinni.com/streaming-service-logos/)
- [LogoDownload](https://www.logodownload.org/)
- **Note**: Always verify licensing and usage rights

## How to Add Icons to Xcode

### Step 1: Prepare Your Images
1. Download or create PNG/PDF files for each platform
2. Recommended sizes:
   - **PNG**: 60x60pt (@1x), 120x120pt (@2x), 180x180pt (@3x)
   - **PDF**: Single vector file (scales automatically)

### Step 2: Create Image Sets in Assets.xcassets
1. Open `Assets.xcassets` in Xcode
2. Right-click in the asset catalog → "New Image Set"
3. Name each image set exactly as follows:
   - `netflix-logo`
   - `prime-video-logo`
   - `disney-plus-logo`
   - `max-logo`
   - `hulu-logo`
   - `criterion-logo`
   - `paramount-plus-logo`
   - `apple-tv-plus-logo`
   - `peacock-logo`
   - `tubi-logo`

### Step 3: Add Images to Image Sets
For **PNG** files:
1. Drag `logo@1x.png` to the 1x slot
2. Drag `logo@2x.png` to the 2x slot
3. Drag `logo@3x.png` to the 3x slot

For **PDF** files:
1. Drag the PDF file to the Universal slot
2. Check "Preserve Vector Data" in the Attributes Inspector
3. Set "Scales" to "Single Scale"

### Step 4: Verify Setup
1. Build and run the app
2. The icons should appear automatically in:
   - Profile page (subscription list)
   - Search categories (platform selection)
3. If images don't appear, colored fallback boxes will show (this is expected until images are added)

## Image Naming Convention
The code expects these exact names (all lowercase with hyphens):
- `netflix-logo`
- `prime-video-logo`
- `disney-plus-logo`
- `max-logo`
- `hulu-logo`
- `criterion-logo`
- `paramount-plus-logo`
- `apple-tv-plus-logo`
- `peacock-logo`
- `tubi-logo`

## Fallback Behavior
If an image is not found in Assets, the app will automatically show a colored box with a letter (the current placeholder design). This ensures the app works even before all icons are added.

## Legal Considerations
⚠️ **Important**: 
- Always review brand guidelines and licensing agreements
- Some logos may require attribution
- Some logos may have restrictions on commercial use
- Ensure compliance with each service's brand guidelines

## Testing
After adding icons:
1. Check Profile page - icons should appear next to platform names
2. Check Search categories - icons should appear in platform cards
3. Verify icons scale properly on different device sizes
4. Test both light and dark mode (if applicable)

## Troubleshooting
- **Icons not showing**: Verify image set names match exactly (case-sensitive)
- **Icons blurry**: Ensure @2x and @3x variants are included for PNG
- **Icons too large/small**: Adjust size parameter in `PlatformIconHelper.icon(for:size:)` calls
- **Build errors**: Ensure all image files are properly added to the target in Xcode




