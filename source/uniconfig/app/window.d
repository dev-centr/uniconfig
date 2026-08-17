module uniconfig.app.window;

import dlangui;
import dlangui.dialogs.filedlg;
import dlangui.dialogs.dialog;
import std.conv : to;
import std.file : exists;
import std.path : baseName;
import std.process : browse;
import uniconfig.core;
import uniconfig.app.cli : makeOpenContext, writeDebugDump;
import uniconfig.app.form;
import uniconfig.app.paths;
import uniconfig.app.versioninfo;

enum PanelAction : int
{
    FileOpen = 1010001,
    FileSave,
    FileSaveAs,
    FileReload,
    FileExit,
    HelpAbout,
    HelpDocs,
    HelpDump,
    CheckUpdates,
    OpenConfigDir,
}

const Action ACTION_PANEL_OPEN = new Action(PanelAction.FileOpen, "Open…"d, "document-open", KeyCode.KEY_O, KeyFlag.Control);
const Action ACTION_PANEL_SAVE = new Action(PanelAction.FileSave, "Save"d, "document-save", KeyCode.KEY_S, KeyFlag.Control);
const Action ACTION_PANEL_SAVE_AS = new Action(PanelAction.FileSaveAs, "Save As…"d);
const Action ACTION_PANEL_RELOAD = new Action(PanelAction.FileReload, "Reload"d);
const Action ACTION_PANEL_EXIT = new Action(PanelAction.FileExit, "Exit"d, "document-close", KeyCode.KEY_X, KeyFlag.Alt);
const Action ACTION_PANEL_ABOUT = new Action(PanelAction.HelpAbout, "About"d);
const Action ACTION_PANEL_DOCS = new Action(PanelAction.HelpDocs, "Documentation"d);
const Action ACTION_PANEL_DUMP = new Action(PanelAction.HelpDump, "Write debug dump"d);
const Action ACTION_PANEL_UPDATES = new Action(PanelAction.CheckUpdates, "Check for updates"d);
const Action ACTION_PANEL_CONFIGDIR = new Action(PanelAction.OpenConfigDir, "Open config folder"d);

class PanelHost : AppFrame
{
    OpenedDocument doc;
    ConfigRegistry registry;
    OpenContext ctx;
    TreeWidget tree;
    HorizontalLayout split;
    Widget formHost;
    string pendingPath;

    this(string pending)
    {
        pendingPath = pending;
        super();
        appCodeName = "uniconfig";
        if (pendingPath.length && exists(pendingPath))
            loadPath(pendingPath);
        else if (registry.files.length && exists(registry.files[0].path))
            loadPath(registry.files[0].path);
    }

    override protected ToolBarHost createToolbars()
    {
        return null;
    }

    override protected MainMenu createMainMenu()
    {
        auto root = new MenuItem();
        auto file = new MenuItem(new Action(1, "File"d));
        file.add(ACTION_PANEL_OPEN, ACTION_PANEL_SAVE, ACTION_PANEL_SAVE_AS, ACTION_PANEL_RELOAD);
        file.addSeparator();
        file.add(ACTION_PANEL_EXIT);
        auto help = new MenuItem(new Action(2, "Help"d));
        help.add(ACTION_PANEL_DOCS, ACTION_PANEL_UPDATES, ACTION_PANEL_CONFIGDIR, ACTION_PANEL_DUMP);
        help.addSeparator();
        help.add(ACTION_PANEL_ABOUT);
        root.add(file);
        root.add(help);
        return new MainMenu(root);
    }

    override protected Widget createBody()
    {
        ctx = makeOpenContext();
        registry = loadRegistry(registryFile());

        tree = new TreeWidget("tree");
        tree.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        tree.selectionChange = delegate(TreeItems source, TreeItem selectedItem, bool activated) {
            if (selectedItem is null)
                return;
            auto id = selectedItem.id;
            if (id.length > 5 && id[0 .. 5] == "file:")
                loadPath(id[5 .. $]);
        };

        auto left = new VerticalLayout();
        left.minWidth(220).layoutWidth(280).layoutHeight(FILL_PARENT);
        left.addChild(new TextWidget(null, "Registry"d).fontWeight(700).padding(8));
        left.addChild(tree);

        formHost = emptyHint();
        formHost.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

        split = new HorizontalLayout();
        split.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        split.addChild(left);
        split.addChild(formHost);
        rebuildRegistryTree();
        return split;
    }

    override bool handleAction(const Action a)
    {
        if (a is null)
            return false;
        switch (a.id)
        {
        case PanelAction.FileOpen:
            openDialog(true);
            return true;
        case PanelAction.FileSave:
            saveCurrent();
            return true;
        case PanelAction.FileSaveAs:
            openDialog(false);
            return true;
        case PanelAction.FileReload:
            if (doc.path.length)
                loadPath(doc.path);
            return true;
        case PanelAction.FileExit:
            if (window)
                window.close();
            return true;
        case PanelAction.HelpAbout:
            showAbout();
            return true;
        case PanelAction.HelpDocs:
            browse(appDocs);
            return true;
        case PanelAction.HelpDump:
            setStatus("Wrote " ~ writeDebugDump());
            return true;
        case PanelAction.CheckUpdates:
            browse(appHomepage ~ "/releases");
            return true;
        case PanelAction.OpenConfigDir:
            browse(userConfigDir());
            return true;
        default:
            return super.handleAction(a);
        }
    }

    void openDialog(bool mustExist)
    {
        uint flags = DialogFlag.Modal | DialogFlag.Resizable;
        if (mustExist)
            flags |= FileDialogFlag.FileMustExist;
        auto dlg = new FileDialog(UIString.fromRaw(mustExist ? "Open config"d : "Save config as"d),
                window, null, flags);
        dlg.addFilter(FileFilterEntry(UIString.fromRaw("Config files"d),
                "*.json;*.json5;*.yml;*.yaml;*.toml;*.ini;*.cfg;*.sdl;*.tfvars;*.hcl"));
        dlg.addFilter(FileFilterEntry(UIString.fromRaw("All files"d), "*.*"));
        dlg.dialogResult = delegate(Dialog dlo, const Action result) {
            if (result.id == ACTION_OPEN.id || result.id == ACTION_SAVE.id || result.id == ACTION_OK.id)
            {
                auto fn = result.stringParam;
                if (fn.length == 0)
                    return;
                if (!mustExist && doc.merged !is null)
                {
                    doc.path = fn;
                    saveCurrent();
                }
                else
                    loadPath(fn);
            }
        };
        dlg.show();
    }

    void loadPath(string path)
    {
        if (!exists(path))
        {
            setStatus("Missing " ~ path);
            return;
        }
        try
        {
            doc = openDocument(path, ctx);
            registerOpened(registry, doc);
            saveRegistry(registry, registryFile());
            rebuildRegistryTree();
            refreshForm();
            if (window)
                window.windowCaption = to!dstring(appDisplayName ~ " — " ~ baseName(path));
            auto miss = missingFields(doc.merged);
            setStatus(statusLineFor(miss.length));
        }
        catch (Exception e)
        {
            setStatus("Failed: " ~ e.msg);
        }
    }

    void saveCurrent()
    {
        if (doc.path.length == 0)
        {
            openDialog(false);
            return;
        }
        try
        {
            saveDocument(doc);
            doc.dirty = false;
            setStatus("Saved " ~ doc.path);
        }
        catch (Exception e)
        {
            setStatus("Save failed: " ~ e.msg);
        }
    }

    void refreshForm()
    {
        auto form = buildForm(doc.merged, {
            doc.dirty = true;
            setStatus("Modified");
        });
        form.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        split.removeChild(formHost);
        formHost = form;
        split.addChild(formHost);
        split.invalidate();
    }

    void rebuildRegistryTree()
    {
        if (tree is null)
            return;
        tree.items.clear();
        auto root = tree.items.newChild("registry", "Opened"d);
        foreach (e; registry.files)
        {
            auto label = e.title.length ? e.title ~ "  (" ~ baseName(e.path) ~ ")" : baseName(e.path);
            root.newChild("file:" ~ e.path, to!dstring(label));
        }
        if (doc.path.length && doc.merged !is null)
        {
            auto keys = tree.items.newChild("keys", "Fields"d);
            walkKeys(keys, doc.merged);
            keys.expand();
        }
        root.expand();
    }

    void walkKeys(TreeItem parent, ConfigNode n)
    {
        foreach (c; n.children)
        {
            auto mark = (!c.fromFile && c.fromSchema) ? " · unset" : "";
            auto kid = parent.newChild("key:" ~ c.path, to!dstring((c.key.length ? c.key : c.path) ~ mark));
            if (c.children.length)
            {
                walkKeys(kid, c);
                kid.expand();
            }
        }
    }

    void showAbout()
    {
        import uniconfig.core.versioninfo : coreName, coreVersion;
        if (window is null)
            return;
        window.showMessageBox(UIString.fromRaw("About "d ~ to!dstring(appDisplayName)),
                UIString.fromRaw(to!dstring(aboutLine() ~ "\n" ~ appTagline
                    ~ "\n" ~ coreName ~ " " ~ coreVersion
                    ~ "\nRenderer: dlangui (optional Vello: dub build -c vello-windows)"
                    ~ "\n" ~ appHomepage)));
    }

    void setStatus(string s)
    {
        if (statusLine)
            statusLine.setStatusText(to!dstring(s));
    }

    private string statusLineFor(size_t missing)
    {
        import std.format : format;
        auto prof = doc.profile.id.length ? doc.profile.id : "on-the-fly";
        return format("%s  ·  %s  ·  %s  ·  %s unset schema field(s)",
                baseName(doc.path), formatName(doc.format), prof, missing);
    }

    private Widget emptyHint()
    {
        auto col = new VerticalLayout();
        col.padding(24).layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        col.addChild(new TextWidget(null, to!dstring(appDisplayName)).fontSize(18).fontWeight(800));
        col.addChild(new TextWidget(null,
                "File → Open a config. Matching profiles register it on the left. Schema fields that are not in the file stay listed so you can include them."d)
            .fontSize(11).margins(Rect(0, 12, 0, 0)));
        return col;
    }
}
