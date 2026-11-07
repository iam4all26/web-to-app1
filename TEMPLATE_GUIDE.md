# Website to App

This template packages a website inside an Android app with a browser-style experience.

## Features

- Website opens inside the app.
- Links using `target="_blank"` and JavaScript `window.open()` create a new in-app tab.
- Tabs can be switched, created and closed without leaving the app.
- Back and forward navigation work independently for each tab.
- HTTP/HTTPS file downloads are handed to Android's native Download Manager.
- Download notifications and completed downloads appear in Android's normal system Downloads experience. There is no separate downloads screen in this app.
- Download requests include the current WebView cookies and user-agent when available, so authenticated downloads can work.

## Configuration

Edit **`app_config.json`**:

```json
{
  "url": "https://example.com",
  "javascript": true,
  "show_loading_bar": true,
  "allow_zoom": false,
  "background_color": "#FFFFFF",
  "open_other_sites_in_app": true
}
```

| Setting | What it does |
| --- | --- |
| `url` | The website the app opens. Use an `https://` address. |
| `javascript` | Enables JavaScript (normally required by modern websites). |
| `show_loading_bar` | Shows a thin progress bar while a page loads. |
| `allow_zoom` | Enables built-in WebView zoom controls. |
| `background_color` | Colour behind the page while it loads, as `#RRGGBB`. |
| `open_other_sites_in_app` | `true` keeps other website links in the app. `false` blocks navigation to a different host. |

## Android download behaviour

Downloads use Android's system `DownloadManager` and are saved in the public **Downloads** folder. Android displays its normal download notification. The app does not create its own downloads list and does not launch Chrome.

The Android native bridge is in:
`android/app/src/main/kotlin/com/mycompany/websiteapp/MainActivity.kt`

If you change `app_package.txt`, update the Kotlin package declaration and folder path to match the new package name.

Some websites prevent downloads, require a special POST request, or use DRM/streaming content. Those site-specific cases may not be downloadable through Android DownloadManager. Regular HTTP/HTTPS file links are supported.

## Name, package name and icon

| What | Where |
| --- | --- |
| App name | `app_name.txt` |
| Package name | `app_package.txt` |
| App icon | `assets/icon/app_icon.png` (512x512 or bigger) |
| Android permissions | `app_permissions.txt` |

## Build

1. Commit and push the project to GitHub.
2. Build an APK or AAB through K-Git Studio.
3. Test a direct PDF/file link and a page link that opens with `target="_blank"`.

The project uses `flutter_inappwebview` for popup/new-window and download callbacks. The Android bridge connects those download callbacks to the system Download Manager.
