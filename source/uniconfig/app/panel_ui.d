module uniconfig.app.panel_ui;

import std.format : format;
import std.path : baseName;
import dew;
import dui;
import dui.forms;
import configui.dui.banner;
import configui.dui.form;
import uniconfig.core;
import uniconfig.app.session;
import uniconfig.app.document_ops;
import uniconfig.app.dui_callbacks : safeClick;
import uniconfig.app.versioninfo;
import uniconfig.app.cli : writeDebugDump;
import std.process : browse;

Widget buildPanelRoot(ref PanelSession s)
{
    if (s.showAbout)
        return buildAboutScreen(s);

    Widget[] leftKids;
    leftKids ~= Text("Registry").fontSize(14).bold();
    foreach (e; s.registry.files)
    {
        auto path = e.path;
        auto label = e.title.length ? format("%s (%s)", e.title, baseName(path)) : baseName(path);
        leftKids ~= Button(label)
            .touchFriendly()
            .width(Length.percent(100))
            .height(36)
            .onClick(safeClick({
                s.pathInput = path;
                loadDocumentPath(s, path);
            }));
    }
    if (!s.registry.files.length)
        leftKids ~= Text("No files yet.").fontSize(11);

    Widget right;
    if (s.doc.merged !is null)
    {
        right = VStack(
            buildDocumentBanner(s.doc),
            buildConfigForm(s.doc.merged, safeClick({
                s.doc.dirty = true;
                s.status = "Modified";
                bump(s);
            }))
        ).spacing(8).width(Length.percent(100)).height(Length.percent(100));
    }
    else
    {
        right = VStack(
            Text(appDisplayName).fontSize(20).bold(),
            Text("Enter a path below or pick a registered file.").fontSize(12)
        ).spacing(8).padding(16);
    }

    auto toolbar = HStack(
        boundTextField(s.pathInput, "Path to config file…"),
        Button("Open").touchFriendly().onClick(safeClick({
            if (s.pathInput.value.length)
                loadDocumentPath(s, s.pathInput.value);
        })),
        Button("Save").touchFriendly().onClick(safeClick({ saveDocumentCurrent(s); })),
        Button("Reload").touchFriendly().onClick(safeClick({
            if (s.doc.path.length)
                loadDocumentPath(s, s.doc.path);
        })),
        Button("About").touchFriendly().onClick(safeClick({
            s.showAbout = true;
            bump(s);
        })),
        Button("Docs").touchFriendly().onClick(() { browse(appDocs); }),
        Button("Dump").touchFriendly().onClick(safeClick({
            s.status = "Wrote " ~ writeDebugDump();
            bump(s);
        })),
    ).spacing(6).width(Length.percent(100));

    auto body = HStack(
        ScrollView(VStack(leftKids).spacing(4).padding(8).width(Length.percent(100)))
            .width(Length.px(280))
            .height(Length.percent(100)),
        ScrollView(right).width(Length.percent(100)).height(Length.percent(100)),
    ).spacing(8).width(Length.percent(100)).height(Length.percent(100));

    return VStack(
        toolbar,
        Text(s.status.value).fontSize(10),
        body
    ).spacing(8).padding(12).width(Length.percent(100)).height(Length.percent(100));
}

private Widget buildAboutScreen(ref PanelSession s)
{
    import uniconfig.core.versioninfo : coreName, coreVersion;
    return VStack(
        Text("About " ~ appDisplayName).fontSize(18).bold(),
        Text(aboutLine()).fontSize(12),
        Text(appTagline).fontSize(11),
        Text(format("%s %s", coreName, coreVersion)).fontSize(11),
        Text("Renderer: dui/dew + Vello").fontSize(11),
        Text(appHomepage).fontSize(11),
        Button("Back").touchFriendly().onClick(safeClick({
            s.showAbout = false;
            bump(s);
        })),
    ).spacing(8).padding(16);
}
