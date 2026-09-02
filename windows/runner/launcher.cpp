#include <windows.h>

#include <string>
#include <vector>

// A small native entry point, independent of the versioned editor runtime.
// The installer owns current-package.txt; no PATH search or shell execution.
int APIENTRY wWinMain(HINSTANCE, HINSTANCE, wchar_t* arguments, int) {
  std::vector<wchar_t> module(32768);
  const DWORD length = GetModuleFileNameW(nullptr, module.data(),
                                         static_cast<DWORD>(module.size()));
  if (length == 0 || length >= module.size()) return 1;
  std::wstring root(module.data(), length);
  root.resize(root.find_last_of(L"\\/"));
  const auto versionParent = root.find_last_of(L"\\/");
  if (versionParent != std::wstring::npos) {
    const std::wstring parent = root.substr(0, versionParent);
    if (parent.substr(parent.find_last_of(L"\\/") + 1) == L"versions") {
      root = parent.substr(0, parent.find_last_of(L"\\/"));
    }
  }
  const std::wstring pointer = root + L"\\current-package.txt";
  HANDLE file = CreateFileW(pointer.c_str(), GENERIC_READ, FILE_SHARE_READ,
                            nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  char bytes[160] = {};
  DWORD read = 0;
  bool valid = file != INVALID_HANDLE_VALUE;
  if (valid) {
    valid = ReadFile(file, bytes, sizeof(bytes), &read, nullptr) &&
            read > 0 && read < sizeof(bytes);
    CloseHandle(file);
  }
  std::wstring package;
  for (DWORD i = 0; valid && i < read; ++i) {
    const char c = bytes[i];
    if (c == '\r' || c == '\n') {
      for (; i < read; ++i) {
        if (bytes[i] != '\r' && bytes[i] != '\n') valid = false;
      }
      break;
    }
    if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') ||
          c == '.' || c == '+' || c == '-')) {
      valid = false;
      break;
    }
    package += static_cast<wchar_t>(c);
  }
  valid = valid && !package.empty() && package.front() >= L'0' &&
          package.front() <= L'9' && package.find(L"..") == std::wstring::npos;
  const std::wstring directory = root + L"\\versions\\" + package;
  const std::wstring executable = directory + L"\\Klipio.exe";
  if (valid && GetFileAttributesW(executable.c_str()) != INVALID_FILE_ATTRIBUTES) {
    std::wstring command = L"\"" + executable + L"\"";
    if (arguments && *arguments) command += L" " + std::wstring(arguments);
    STARTUPINFOW startup = {};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process = {};
    if (CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr,
                       FALSE, 0, nullptr, directory.c_str(), &startup, &process)) {
      CloseHandle(process.hThread);
      CloseHandle(process.hProcess);
      return 0;
    }
  }
  MessageBoxW(nullptr, L"Klipio could not open its installed version. Run the latest Klipio Setup to repair the installation. Your projects will be preserved.",
              L"Klipio", MB_OK | MB_ICONERROR);
  return 1;
}
