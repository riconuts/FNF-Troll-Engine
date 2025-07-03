#include "darkmode.hpp"

#ifdef HX_WINDOWS

#include <Windows.h>
#include <dwmapi.h>
#include <vector>
#include <string>
#include <stdexcept>

using namespace std;

/**
 * @see https://github.com/TBar09/hxWindowColorMode-main/
 */
void setDarkMode(bool isDark)
{
    int darkMode = isDark;
    HWND window = GetActiveWindow();
    if (S_OK != DwmSetWindowAttribute(window, 19, &darkMode, sizeof(darkMode)))
    {
        DwmSetWindowAttribute(window, 20, &darkMode, sizeof(darkMode));
    }
    UpdateWindow(window);
}

/**
 * @see https://stackoverflow.com/questions/51334674/how-to-detect-windows-10-light-dark-mode-in-win32-application
 */
bool isLightTheme()
{
    // The value is expected to be a REG_DWORD, which is a signed 32-bit little-endian
    auto buffer = std::vector<char>(4);
    auto cbData = static_cast<DWORD>(buffer.size() * sizeof(char));
    auto res = RegGetValueW(
        HKEY_CURRENT_USER,
        L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
        L"AppsUseLightTheme",
        RRF_RT_REG_DWORD, // expected value type
        nullptr,
        buffer.data(),
        &cbData);

    if (res != ERROR_SUCCESS)
    {
        throw runtime_error("Error: error_code=" + to_string(res));
    }

    // convert bytes written to our buffer to an int, assuming little-endian
    auto i = int(buffer[3] << 24 |
                 buffer[2] << 16 |
                 buffer[1] << 8 |
                 buffer[0]);

    return i == 1;
}

#else
void setDarkMode(bool isDark) {}
bool isLightTheme() { return true; }
#endif