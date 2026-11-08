# Website to App

This project shows your website inside an Android app. The website stays in the app. Secondary pages open in Chrome, and downloads use Android's normal Downloads.

## The one file to edit

**`app_config.json`**

```json
{
  "url": "https://example.com",
  "javascript": true,
  "background_color": "#FFFFFF",
  "open_links_externally": "auto",
  "new_window_mode": "in_app",
  "enable_downloads": true,
  "enable_print": false,
  "enable_share": false,
  "adapt_width": false,
  "allow_zoom": false,
  "screen_orientation": "auto",
  "pull_to_refresh": true,
  "show_loader": true,
  "update_always": false,
  "allow_offline": true,
  "offline_message": "",
  "user_agent": "",
  "custom_headers": {}
}
```

| Setting | Values | What it does |
| --- | --- | --- |
| `url` | `https://...` | The website the app opens. |
| `javascript` | true / false | Keep `true` unless your site works without JavaScript. |
| `background_color` | `#RRGGBB` | Colour behind the page while it loads. |
| `open_links_externally` | `auto` / `yes` / `no` | `auto`: links meant for a new tab or window (`target="_blank"`, `window.open`) open in Chrome, normal links stay in the app. `yes`: every link to another website and every new window opens in Chrome. `no`: everything stays in the app. |
| `new_window_mode` | `in_app` / `chrome` | Where new tabs and outside links open. `in_app` (default): a page on top of your app with a close button; Back returns to the app, and Chrome is never opened. `chrome`: a Chrome Custom Tab. A link that is a file (PDF, ZIP, APK and similar) or turns into a download is saved to Downloads and no page stays open. |
| `enable_downloads` | true / false | `true`: files go to Android's Download Manager (Downloads folder and notification). `false`: downloads are blocked. |
| `enable_print` | true / false | Handles `window.print()` and adds a "Print this page" item to the small menu button. |
| `enable_share` | true / false | Adds "Share this page" to the small menu button. |
| `adapt_width` | true / false | Forces the page to fit the phone width. |
| `allow_zoom` | true / false | Lets the user pinch to zoom. |
| `screen_orientation` | `auto` / `portrait` / `landscape` | Locks the screen direction. |
| `pull_to_refresh` | true / false | Pull down to reload. |
| `show_loader` | true / false | Thin progress bar while a page loads. |
| `update_always` | true / false | `true`: never use the cache, always fetch fresh pages. |
| `allow_offline` | true / false | When there is no connection, show the last cached copy of the page if one exists. |
| `offline_message` | text | Message on the error screen. Empty uses the default. |
| `user_agent` | text | Custom browser identity. Empty uses the default. |
| `custom_headers` | object | Extra headers sent with the first page request and with downloads, for example `{"X-App": "mobile"}`. |

Old projects that use `show_loading_bar` or `open_other_sites_in_app` keep working.

## What to know

- The small menu button (bottom right) appears only when print or share is on.
- Phone links such as `tel:`, `mailto:` and `whatsapp:` always open the matching app.
- Downloads started from `blob:` or `data:` links are not supported. Normal file links are.
- Custom headers cannot be added to every request the page makes, only to the first load and to downloads.
- On Android 9 and older, if the system refuses a download, the link is handed to Chrome instead.
- There is no tab switcher and no downloads screen inside the app, on purpose.

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
3. To change a setting, edit `app_config.json`, then commit, push and build again.

Do not change `lib/` or `packages/` unless you know Flutter and Android.

`packages/flutter_inappwebview_android` is a patched copy of the WebView plugin so it builds with current Android tools. Leave it as it is.
