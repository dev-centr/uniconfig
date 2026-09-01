module uniconfig.app.banner;

import dlangui;
import std.conv : to;
import std.path : baseName, dirName;
import std.process : browse;
import uniconfig.core;

/// Chrome above the form: format, links to spec/codec/file/repository.
Widget buildDocumentBanner(const OpenedDocument doc)
{
    auto box = new VerticalLayout("doc_banner");
    box.layoutWidth(FILL_PARENT).padding(8).backgroundColor(0xF4F4F4);

    auto title = new TextWidget(null, to!dstring(doc.profile.title.length ? doc.profile.title : baseName(doc.path)));
    title.fontSize(13).fontWeight(800);
    box.addChild(title);

    auto meta = new TextWidget(null,
        to!dstring(formatName(doc.format) ~ "  ·  " ~ (doc.profile.id.length ? doc.profile.id : "on-the-fly")));
    meta.fontSize(10).textColor(0x555555).margins(Rect(0, 4, 0, 8));
    box.addChild(meta);

    auto row = new HorizontalLayout();
    row.layoutWidth(FILL_PARENT);

    auto spec = formatSpecUrl(doc.format);
    if (spec.length)
        row.addChild(linkButton("Format spec"d, spec));

    row.addChild(linkButton("Codec source"d, "https://github.com/dev-centr/uniconfig-core"));

    auto folderBtn = new Button(null, "Open file folder"d);
    folderBtn.margins(Rect(0, 0, 8, 0));
    folderBtn.click = delegate(Widget w) {
        browse(dirName(doc.path));
        return true;
    };
    row.addChild(folderBtn);

    if (doc.profile.repositoryClosedSource)
    {
        auto closed = new TextWidget(null, "Repository: closed source"d);
        closed.fontSize(10).textColor(0x999999).margins(Rect(8, 6, 0, 0));
        row.addChild(closed);
    }
    else if (doc.profile.repositoryUrl.length)
        row.addChild(linkButton("Publisher repository"d, doc.profile.repositoryUrl));

    box.addChild(row);
    return box;
}

private Widget linkButton(dstring label, string url)
{
    auto b = new Button(null, label);
    b.margins(Rect(0, 0, 8, 0));
    b.click = delegate(Widget w) {
        browse(url);
        return true;
    };
    return b;
}
