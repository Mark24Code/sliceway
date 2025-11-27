# PSD Management System Walkthrough

## Overview
We have built a local PSD management system that allows you to:
1.  **Upload PSD files** to create projects.
2.  **Automatically process** PSDs to extract layers, groups, and slices.
3.  **View** the PSD content in a "Full List" or "Interactive View".
4.  **Export** specific layers or groups to a local directory.

## Features

### 1. Project Management
*   **List View:** Shows all imported projects with their status (Processing, Ready).
*   **Create Project:** Upload a PSD file and set an optional export path.
*   **Delete Project:** Remove projects and their associated files.

### 2. Interactive View
This is the core feature for inspecting PSDs.
*   **Scanner Preview (Top):** Displays the full PSD. As you scroll, a red reference line stays centered, simulating a scanner.
*   **Filter List (Bottom):** Automatically filters and shows layers that intersect with the scanner line.
    *   **Tabs:** Filter by "All", "Equidistant" (Icons), "Text", "No Text", "With Text".
    *   **Hover:** Hovering a layer in the list highlights it in the top preview.
    *   **Selection:** Click to select multiple layers for export.
*   **Detail Panel (Right):** Shows details for the selected layer, including a CSS snippet generator.

### 3. Export
*   **Batch Export:** Select multiple layers in the Interactive View or Full List View and click "Export".
*   **Formats:**
    *   **Layers/Slices:** Exported as PNG.
    *   **Groups:** Exported in two versions:
        *   `_with_text.png`: Full group composition.
        *   `_no_text.png`: Group composition with text layers hidden (best effort).

## How to Run

### Backend
```bash
cd /Users/bilibili/Labspace/psd2img
bundle install
ruby app.rb
```
Server runs on `http://localhost:4567`.

### Frontend
```bash
cd /Users/bilibili/Labspace/psd2img/frontend
npm install
npm run dev
```
Frontend runs on `http://localhost:5173`.

## Verification Results
*   **Backend:** Verified with `sample.psd`. Processing extracts layers and groups correctly.
*   **Frontend:** UI components are implemented. Interactive view logic connects scanner position to layer filtering.

## Next Steps
*   **Polish:** Improve the "No Text" rendering logic if complex blending modes are used.
*   **Performance:** Optimize large PSD rendering.
