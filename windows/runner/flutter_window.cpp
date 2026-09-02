#include "flutter_window.h"

#include <cstdint>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

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

  process_job_ = ::CreateJobObjectW(nullptr, nullptr);
  if (process_job_ != nullptr) {
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
    limits.BasicLimitInformation.LimitFlags =
        JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | JOB_OBJECT_LIMIT_PRIORITY_CLASS;
    limits.BasicLimitInformation.PriorityClass = BELOW_NORMAL_PRIORITY_CLASS;
    if (!::SetInformationJobObject(
            process_job_, JobObjectExtendedLimitInformation, &limits,
            sizeof(limits))) {
      ::CloseHandle(process_job_);
      process_job_ = nullptr;
    }
    if (process_job_ != nullptr) {
      JOBOBJECT_CPU_RATE_CONTROL_INFORMATION cpu_limits{};
      cpu_limits.ControlFlags = JOB_OBJECT_CPU_RATE_CONTROL_ENABLE |
                                JOB_OBJECT_CPU_RATE_CONTROL_HARD_CAP;
      // Heavy media and speech workers share at most 70% of total CPU. This
      // reserves enough capacity for Windows, input, and Flutter's UI thread.
      cpu_limits.CpuRate = 7000;
      ::SetInformationJobObject(process_job_, JobObjectCpuRateControlInformation,
                                &cpu_limits, sizeof(cpu_limits));
    }
  }

  process_job_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "klipio/process_job",
          &flutter::StandardMethodCodec::GetInstance());
  process_job_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() != "registerWorker") {
          result->NotImplemented();
          return;
        }
        if (process_job_ == nullptr || call.arguments() == nullptr) {
          result->Success(flutter::EncodableValue(false));
          return;
        }
        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments == nullptr) {
          result->Error("bad_arguments", "Expected a PID map.");
          return;
        }
        const auto pid_value = arguments->find(flutter::EncodableValue("pid"));
        if (pid_value == arguments->end()) {
          result->Error("bad_arguments", "Missing worker PID.");
          return;
        }
        DWORD pid = 0;
        if (const auto* int32_value =
                std::get_if<int32_t>(&pid_value->second)) {
          pid = static_cast<DWORD>(*int32_value);
        } else if (const auto* int64_value =
                       std::get_if<int64_t>(&pid_value->second)) {
          pid = static_cast<DWORD>(*int64_value);
        }
        HANDLE process = ::OpenProcess(
            PROCESS_SET_QUOTA | PROCESS_TERMINATE | PROCESS_SET_INFORMATION |
                PROCESS_QUERY_LIMITED_INFORMATION,
            FALSE, pid);
        const bool assigned = process != nullptr &&
                            ::AssignProcessToJobObject(process_job_, process);
        const auto background = arguments->find(flutter::EncodableValue("background"));
        if (process != nullptr && background != arguments->end()) {
          const auto* enabled = std::get_if<bool>(&background->second);
          if (enabled != nullptr && *enabled) {
            // UI/native playback and export retain normal priority. Cache
            // preparation yields CPU scheduling priority when they compete.
            ::SetPriorityClass(process, BELOW_NORMAL_PRIORITY_CLASS);
          }
        }
        if (process != nullptr) ::CloseHandle(process);
        result->Success(flutter::EncodableValue(assigned));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

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
  process_job_channel_.reset();
  if (process_job_ != nullptr) {
    ::CloseHandle(process_job_);
    process_job_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Kill every registered FFmpeg/Python descendant before Flutter/plugin
  // shutdown. This path is native, so the window close button still works if
  // Dart is stalled or a modal progress dialog is open.
  if ((message == WM_CLOSE || message == WM_QUERYENDSESSION) &&
      process_job_ != nullptr) {
    ::CloseHandle(process_job_);
    process_job_ = nullptr;
  }
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
