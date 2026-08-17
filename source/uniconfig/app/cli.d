module uniconfig.app.cli;

import std.stdio : writeln, stderr, File;
import std.string : startsWith;
import std.file : write;
import std.path : baseName;
import uniconfig.core;
import uniconfig.app.versioninfo;
import uniconfig.app.paths;

/// Returns true if the process should exit without opening a window.
bool runCli(string[] args, out int exitCode, out string openPath)
{
    exitCode = 0;
    openPath = "";
    if (args.length <= 1)
        return false;

    auto rest = args[1 .. $];
    if (rest[0] == "--version" || rest[0] == "-V")
    {
        writeln(aboutLine());
        return true;
    }
    if (rest[0] == "--help" || rest[0] == "-h")
    {
        writeln(helpText());
        return true;
    }
    if (rest[0] == "debug-dump" || rest[0] == "--debug-dump")
    {
        auto p = writeDebugDump();
        writeln(p);
        return true;
    }
    if (rest[0] == "dump" && rest.length >= 2)
    {
        dumpFile(rest[1]);
        return true;
    }
    if (rest[0] == "validate" && rest.length >= 2)
    {
        validateFile(rest[1]);
        return true;
    }
    if (!rest[0].startsWith("-"))
    {
        openPath = rest[0];
        return false;
    }
    stderr.writeln("unknown option: ", rest[0]);
    stderr.writeln(helpText());
    exitCode = 2;
    return true;
}

string helpText()
{
    return appDisplayName ~ " " ~ appVersion ~ `
` ~ appTagline ~ `

Usage:
  uniconfig [FILE]
  uniconfig dump FILE
  uniconfig validate FILE
  uniconfig debug-dump
  uniconfig --version
  uniconfig --help

Opens a schema-driven panel for JSON, JSON5, YAML, TOML, INI/cfg, SDLang, and HCL-lite (.tfvars).
Docs: ` ~ appDocs;
}

void dumpFile(string path)
{
    import std.json : toJSON;
    auto ctx = makeOpenContext();
    auto d = openDocument(path, ctx);
    auto j = d.merged.toJson();
    writeln(toJSON(j, true));
    auto missing = missingFields(d.merged);
    if (missing.length)
    {
        writeln("# unset schema fields:");
        foreach (f; missing)
            writeln("#   ", f.path, " — ", f.description.length ? f.description : f.type);
    }
}

void validateFile(string path)
{
    auto ctx = makeOpenContext();
    auto d = openDocument(path, ctx);
    bool ok = true;
    foreach (n; d.merged.walkLeaves)
    {
        if (n.required && displayValue(n).length == 0)
        {
            writeln("missing required: ", n.path);
            ok = false;
        }
    }
    if (ok)
        writeln("ok");
}

OpenContext makeOpenContext()
{
    OpenContext ctx;
    auto dir = bundledProfilesDir();
    ctx.bundledSchemaDir = dir;
    ctx.profileCatalogDir = dir;
    auto cat = buildPathSafe(dir, "catalog.sdl");
    import std.file : exists;
    if (exists(cat))
        ctx.profiles = loadProfileCatalogFile(cat);
    else
        ctx.profiles = loadProfileDirectory(dir);
    return ctx;
}

private string buildPathSafe(string a, string b)
{
    import std.path : buildPath;
    return buildPath(a, b);
}

string writeDebugDump()
{
    import std.datetime : Clock;
    import std.process : environment;
    import uniconfig.core.versioninfo : coreName, coreVersion;
    auto p = debugDumpPath();
    auto s = aboutLine() ~ "\n"
        ~ coreName ~ " " ~ coreVersion ~ "\n"
        ~ "time=" ~ Clock.currTime.toISOExtString ~ "\n"
        ~ "profiles=" ~ bundledProfilesDir() ~ "\n"
        ~ "registry=" ~ registryFile() ~ "\n"
        ~ "HOME=" ~ environment.get("HOME", "") ~ "\n"
        ~ "LOCALAPPDATA set=" ~ (environment.get("LOCALAPPDATA").length ? "yes" : "no") ~ "\n";
    write(p, s);
    return p;
}
