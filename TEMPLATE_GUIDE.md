# Website to App

This project shows your website inside an Android app.

## The one file to edit

**`app_config.json`**

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
| `javascript` | Keep `true` unless your site works without JavaScript. |
| `show_loading_bar` | Shows a thin progress bar while a page loads. |
| `allow_zoom` | Lets the user pinch to zoom. |
| `background_color` | Colour behind the page while it loads, as `#RRGGBB`. |
| `open_other_sites_in_app` | `false` blocks links that leave your website. |

## Name, package name and icon

| What | Where |
| --- | --- |
| App name | `app_name.txt` |
| Package name | `app_package.txt` (example `com.company.app`) |
| App icon | `assets/icon/app_icon.png` (a square PNG, 512x512 or bigger) |
| Permissions | `app_permissions.txt` (Internet is already included) |

## Build it

1. Commit and push the project to GitHub.
2. Open **New Build** in K-Git Studio and build an APK to try it, or an AAB for Google Play.
3. To change the website later, edit `app_config.json`, then commit, push and build again.

Do not change `lib/main.dart` unless you know Flutter.
