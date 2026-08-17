module uniconfig.app.paths;

import std.file : thisExePath, exists, isDir, mkdirRecurse;
import std.path : buildPath, dirName;
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
