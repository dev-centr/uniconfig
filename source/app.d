module app;

import uniconfig.app.cli;
import uniconfig.app.session;
import uniconfig.app.dui_host;
import uniconfig.app.document_ops;
import std.file : exists;

int main(string[] args)
{
    int exitCode;
    string openPath;
    if (runCli(args, exitCode, openPath))
        return exitCode;

    PanelSession session;
    initPanelSession(session, openPath);
    if (openPath.length && exists(openPath))
        loadDocumentPath(session, openPath);
    else if (session.registry.files.length && exists(session.registry.files[0].path))
        loadDocumentPath(session, session.registry.files[0].path);

    version (ConfigUIWindowed)
        runWindowedPanel(session);
    else
        runHeadlessPanel(session);
    return 0;
}
