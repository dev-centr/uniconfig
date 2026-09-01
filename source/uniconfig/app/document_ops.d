module uniconfig.app.document_ops;

import std.exception : enforce;
import std.file : exists;
import std.format : format;
import std.path : baseName;
import uniconfig.core;
import uniconfig.app.session;
import uniconfig.app.paths : registryFile;

bool loadDocumentPath(ref PanelSession s, string path)
{
    if (!exists(path))
    {
        s.status = "Missing " ~ path;
        bump(s);
        return false;
    }
    try
    {
        s.doc = openDocument(path, s.ctx);
        registerOpened(s.registry, s.doc);
        saveRegistry(s.registry, registryFile());
        auto miss = missingFields(s.doc.merged);
        s.status = format("%s  ·  %s  ·  %s unset field(s)",
            baseName(s.doc.path), formatName(s.doc.format), miss.length);
        bump(s);
        return true;
    }
    catch (Exception e)
    {
        s.status = "Failed: " ~ e.msg;
        bump(s);
        return false;
    }
}

bool saveDocumentCurrent(ref PanelSession s)
{
    enforce(s.doc.path.length > 0, "No path — enter a save path first");
    try
    {
        saveDocument(s.doc);
        s.doc.dirty = false;
        s.status = "Saved " ~ s.doc.path;
        bump(s);
        return true;
    }
    catch (Exception e)
    {
        s.status = "Save failed: " ~ e.msg;
        bump(s);
        return false;
    }
}
