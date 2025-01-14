# Spritesheet Tools

A single-scene tool that used to generate spritesheets from a folder of images, and split spritesheets into individual images.

There are three main modes:

1. Pack to spritesheet: Combines multiple images into a single spritesheet.
2. Crop to cells: Splits a larger spritesheet into smaller, evenly sized cells.
3. Split single image: Extracts a custom-sized image from a specific area of a larger image.

## Brief description

The Spritesheet Tool is a single-scene utility designed for managing spritesheets and individual images. It provides three main functions:

1. Pack to Spritesheet: Combines multiple images into a single spritesheet with customizable properties such as size, offsets, and margins.
2. Crop to Cells: Splits a large spritesheet into evenly sized grid cells, supporting adjustments for cell size, margins, and offsets.
3. Split Single Image: Extracts a specific region from a larger image as a separate file using a simple click-and-drag interface.

The tool features a user-friendly UI with options to select files, configure properties, preview results, and save outputs in a specified directory.

## UI components usage description

![spritesheet-tool-ui](images/spritesheet-tool-ui.png)

1. Mode selector: A dropdown menu that allows users to switch between three distinct modes
2. File path area: A large text area for displaying or inputting the file paths of images to be processed.
3. File operation buttons:
   1. Select File: Opens a file picker to choose an image or multiple images(supported formats: **png, jpg, jpeg**).
   2. Reload File: Reloads the currently selected file(s), refreshing the display.
4. Spritesheet Properties(not available in split-single-image mode)
   1. Width/Height:
      1. In pack-to-spritesheet mode: Specifies the width of the spritesheet in pixels (default shown is 2048/1024).
      2. In crop-to-cells mode: Specifies the width of every single cell in pixels (default shown is 128/128).
   2. Offset X/Y: Adjusts the starting position (offset) of the sprites in the X and Y directions (default is 0 for both).
   3. Margin X/Y: Sets the margin between sprites in both directions (default shown is 1).
5. Generate: Executes the chosen mode operation (e.g., packing, cropping, or splitting).
6. Output Path: Displays the path to the directory where the output will be saved, **the path must start with 'user://'** (user://export/ by default).
7. Save Files: Saves the output spritesheet or individual sprite files to the specified directory.
8. Preview Area: Show the preview spritesheet(s) or grid lines in crop-to-cells mode.
9. Preview Page Navigation: Support multi-page previews and outputs.

## Step-by-step usage

### Pack to spritesheet

1. Click `Select File` button to select multiple files from a file picker dialog.
2. Change the `Width/Height/Offset/Margin` properties to according to the needs.
3. Click `Generate` button and then the spritesheet(s) can be shown in the preview area.
4. Type in the specific output path in the export edit area, **the path must start with 'user://'**.
5. Click `Save Files` button and wait for the saving process ends, then the saved files can be found in the export path.

### Crop to cells

1. Click `Select File` button to select a single file from a file picker dialog.
2. Change the `Width/Height/Offset/Margin` properties to according to the needs.
3. Click `Generate` button and then the grid lines can be shown in the preview area.
4. Type in the specific output path in the export edit area, **the path must start with 'user://'**.
5. Click `Save Files` button and wait for the saving process ends, then the saved files can be found in the export path.

### Split single image

1. Click `Select File` button to select a single file from a file picker dialog.
2. Click `Generate` button and then the preview image can be shown in the preview area.
3. Click and drag and a rectangle area is shown that indicates which area will be splited to a single image.
4. Type in the specific output path in the export edit area, **the path must start with 'user://'**.
5. Click `Save Files` button and wait for the saving process ends, then the saved file can be found in the export path.