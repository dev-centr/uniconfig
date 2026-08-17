module app;

import dlangui;
import std.conv : to;
import uniconfig.app.cli;
import uniconfig.app.versioninfo;
import uniconfig.app.window;

mixin APP_ENTRY_POINT;

extern (C) int UIAppMain(string[] args)
{
    int exitCode;
    string openPath;
    if (runCli(args, exitCode, openPath))
        return exitCode;

    Platform.instance.uiLanguage = "en";
    Platform.instance.uiTheme = "theme_default";

    auto win = Platform.instance.createWindow(to!dstring(appDisplayName), null, WindowFlag.Resizable, 1100, 720);
    win.mainWidget = new PanelHost(openPath);
    win.show();
    return Platform.instance.enterMessageLoop();
}
