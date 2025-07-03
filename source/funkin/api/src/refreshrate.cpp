#ifdef HX_LINUX
#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>

// https://stackoverflow.com/questions/17797636/c-linux-get-the-refresh-rate-of-a-monitor
short getMonitorRefreshRate()
{
    Display *dpy = XOpenDisplay(NULL);
    Window root = RootWindow(dpy, 0);
    XRRScreenConfiguration *conf = XRRGetScreenInfo(dpy, root);
    short current_rate = XRRConfigCurrentRate(conf);
    XCloseDisplay(dpy);

    return current_rate;
}
#else
short getMonitorRefreshRate() { 
    throw "This function should only be used on Linux!\nUse 'FlxG.stage.window.displayMode.refreshrate' on other platforms!";
    return 0; 
}
#endif