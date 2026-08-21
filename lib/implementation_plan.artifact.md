# GitHub Upload and Windows EXE Generation

I will prepare the project for a professional Windows distribution by renaming the binary, fixing the GitHub Actions workflow, and providing instructions for the upload.

## User Review Required

> [!IMPORTANT]
> I am renaming the Windows binary from `mobile.exe` to `presentation_pro.exe`. I am also updating the GitHub workflow to use a valid Flutter version (`3.24.2`) and to automatically create a **GitHub Release** whenever you push a tag.

## Proposed Changes

### Windows Configuration
#### [MODIFY] [CMakeLists.txt](file:///Users/miurin/Desktop/painting_tool_co_rasel/mobile/windows/CMakeLists.txt)
- Change `project(mobile LANGUAGES CXX)` to `project(presentation_pro LANGUAGES CXX)`.
- Change `set(BINARY_NAME "mobile")` to `set(BINARY_NAME "presentation_pro")`.

#### [MODIFY] [Runner.rc](file:///Users/miurin/Desktop/painting_tool_co_rasel/mobile/windows/runner/Runner.rc)
- Update `FileDescription`, `InternalName`, and `ProductName` to "Presentation Pro".
- Update `OriginalFilename` to `presentation_pro.exe`.

### GitHub Workflow
#### [MODIFY] [build-windows.yml](file:///Users/miurin/Desktop/painting_tool_co_rasel/mobile/.github/workflows/build-windows.yml)
- Update Flutter version to `3.24.2`.
- Add a step to create a **GitHub Release** using `softprops/action-gh-release`.
- Configure the release to trigger on tags (e.g., `v1.0.0`) or manually.

## Verification Plan

### Manual Verification
1.  **Local Build Test**: If a Windows machine were available, we would run `flutter build windows`. (I will rely on the CI for this).
2.  **Workflow Syntax**: Verify the `.yml` syntax is correct for GitHub Actions.

## Deployment Instructions

Once the changes are applied, follow these steps in your terminal:

1.  **Commit everything**:
    ```bash
    git add .
    git commit -m "Prepare for Windows release and optimize PPTX loading"
    ```

2.  **Push to GitHub**:
    ```bash
    git push origin main
    ```

3.  **Create a Release Tag** (to trigger the EXE generation):
    ```bash
    git tag v1.0.0
    git push origin v1.0.0
    ```

The `.exe` will be available in the **Releases** section of your GitHub repository.
