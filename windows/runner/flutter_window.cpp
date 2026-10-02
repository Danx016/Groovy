#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr int kHotkeyNextTrack = 101;
constexpr int kHotkeyPrevTrack = 102;
constexpr int kHotkeyPlayPause = 103;
constexpr int kHotkeyStop = 104;
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  media_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.groovy.music/windows_media_keys",
          &flutter::StandardMethodCodec::GetInstance());

  HWND hwnd = GetHandle();
  if (hwnd) {
    RegisterHotKey(hwnd, kHotkeyNextTrack, 0, VK_MEDIA_NEXT_TRACK);
    RegisterHotKey(hwnd, kHotkeyPrevTrack, 0, VK_MEDIA_PREV_TRACK);
    RegisterHotKey(hwnd, kHotkeyPlayPause, 0, VK_MEDIA_PLAY_PAUSE);
    RegisterHotKey(hwnd, kHotkeyStop, 0, VK_MEDIA_STOP);
  }

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  HWND hwnd = GetHandle();
  if (hwnd) {
    UnregisterHotKey(hwnd, kHotkeyNextTrack);
    UnregisterHotKey(hwnd, kHotkeyPrevTrack);
    UnregisterHotKey(hwnd, kHotkeyPlayPause);
    UnregisterHotKey(hwnd, kHotkeyStop);
  }

  media_channel_ = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_HOTKEY: {
      if (media_channel_) {
        switch (wparam) {
          case kHotkeyNextTrack:
            media_channel_->InvokeMethod("skipNext", nullptr);
            return 0;
          case kHotkeyPrevTrack:
            media_channel_->InvokeMethod("skipPrevious", nullptr);
            return 0;
          case kHotkeyPlayPause:
            media_channel_->InvokeMethod("togglePlayPause", nullptr);
            return 0;
          case kHotkeyStop:
            media_channel_->InvokeMethod("stop", nullptr);
            return 0;
        }
      }
      break;
    }
    case WM_APPCOMMAND: {
      const short cmd = GET_APPCOMMAND_LPARAM(lparam);
      if (media_channel_) {
        switch (cmd) {
          case APPCOMMAND_MEDIA_NEXTTRACK:
          case APPCOMMAND_MEDIA_FAST_FORWARD:
            media_channel_->InvokeMethod("skipNext", nullptr);
            return TRUE;
          case APPCOMMAND_MEDIA_PREVIOUSTRACK:
          case APPCOMMAND_MEDIA_REWIND:
            media_channel_->InvokeMethod("skipPrevious", nullptr);
            return TRUE;
          case APPCOMMAND_MEDIA_PLAY_PAUSE:
            media_channel_->InvokeMethod("togglePlayPause", nullptr);
            return TRUE;
          case APPCOMMAND_MEDIA_PLAY:
            media_channel_->InvokeMethod("play", nullptr);
            return TRUE;
          case APPCOMMAND_MEDIA_PAUSE:
            media_channel_->InvokeMethod("pause", nullptr);
            return TRUE;
          case APPCOMMAND_MEDIA_STOP:
            media_channel_->InvokeMethod("stop", nullptr);
            return TRUE;
        }
      }
      break;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
