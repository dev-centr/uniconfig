module uniconfig.app.paths;

import std.file : thisExePath, exists, isDir, mkdirRecurse;
import std.path : buildPath, dirName;
import std.algorithm : splitter;
import std.string : strip;
import uniconfig.core.registry : defaultConfigDir, defaultRegistryPath;

string bundledProfilesDir()
{
    auto nextToExe = buildPath(dirName(thisExePath), "profiles");
    if (exists(nextToExe) && isDir(nextToExe))
        return nextToExe;
    auto cwd = buildPath("profiles");
    if (exists(cwd) && isDir(cwd))
        return cwd;
    return nextToExe;
}

string userConfigDir()
{
    auto d = defaultConfigDir();
    mkdirRecurse(d);
    return d;
}

string registryFile()
{
    return defaultRegistryPath();
}

string debugDumpPath()
{
    return buildPath(userConfigDir(), "debug-dump.txt");
}

string catalogIndexFile()
{
    import uniconfig.core : defaultCatalogIndexPath;
    return defaultCatalogIndexPath();
}

/// Locate ConfigUI / uniconfig executable: sibling, PATH, common install dirs.
string findConfigUiExecutable()
{
    import std.process : environment;
    import std.path : buildPath;

    auto sibling = buildPath(dirName(thisExePath), "uniconfig.exe");
    if (exists(sibling))
        return sibling;
    sibling = buildPath(dirName(thisExePath), "uniconfig");
    if (exists(sibling))
        return sibling;

    version (Windows)
    {
        auto local = environment.get("LOCALAPPDATA");
        if (local.length)
        {
            auto installed = buildPath(local, "Programs", "ConfigUI", "uniconfig.exe");
            if (exists(installed))
                return installed;
        }
    }

    auto pathEnv = environment.get("PATH");
    if (pathEnv.length)
    {
        version (Windows)
            enum sep = ";";
        else
            enum sep = ":";
        foreach (part; pathEnv.splitter(sep))
        {
            auto candidate = buildPath(part.strip, "uniconfig.exe");
            if (exists(candidate))
                return candidate;
            candidate = buildPath(part.strip, "uniconfig");
            if (exists(candidate))
                return candidate;
        }
    }
    return "";
}

bool configUiAlreadyInstalled()
{
    return findConfigUiExecutable().length > 0;
}
