#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>

//https://stackoverflow.com/questions/17797636/c-linux-get-the-refresh-rate-of-a-monitor
short getMonitorRefreshRate()
{
    Display *dpy = XOpenDisplay(NULL);
    Window root = RootWindow(dpy, 0);
    XRRScreenConfiguration *conf = XRRGetScreenInfo(dpy, root);
    short current_rate = XRRConfigCurrentRate(conf);
    XCloseDisplay(dpy);

    return current_rate;
}