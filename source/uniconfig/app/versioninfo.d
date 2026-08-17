module uniconfig.app.versioninfo;

enum string appName = "uniconfig";
enum string appDisplayName = "UniConfig Config Panel";
enum string appVersion = "0.1.0";
enum string appTagline = "Schema-driven Control Panel for config files";
enum string appHomepage = "https://github.com/dev-centr/uniconfig";
enum string appDocs = "https://docs.devcentr.org/uniconfig/latest/";

string buildId()
{
    version (BuildId_CI)
        return "ci";
    else
        return "local";
}

string aboutLine()
{
    import std.string : format;
    return format("%s %s (build %s)", appName, appVersion, buildId());
}
