module uniconfig.app.session;

import dui;
import uniconfig.core;
import uniconfig.app.cli : makeOpenContext;
import uniconfig.app.paths : registryFile;

struct PanelSession
{
    OpenedDocument doc;
    ConfigRegistry registry;
    OpenContext ctx;
    State!int tick = State!int(0);
    State!string status = State!string("Ready");
    State!string pathInput = State!string("");
    bool showAbout;
}

void initPanelSession(ref PanelSession s, string pendingPath)
{
    s.ctx = makeOpenContext();
    s.registry = loadRegistry(registryFile());
    if (pendingPath.length)
        s.pathInput = pendingPath;
}

void bump(ref PanelSession s)
{
    s.tick = s.tick.value + 1;
}
