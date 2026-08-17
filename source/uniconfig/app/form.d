module uniconfig.app.form;

import dlangui;
import std.conv : to;
import std.json : JSONType;
import uniconfig.core.tree;

/// Build a scrolling form of schema-aware controls for `root` (object).
Widget buildForm(ConfigNode root, void delegate() onDirty)
{
    auto scroll = new ScrollWidget("form_scroll");
    scroll.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    auto col = new VerticalLayout("form_col");
    col.layoutWidth(FILL_PARENT).padding(12);
    if (root is null)
    {
        col.addChild(new TextWidget(null, "Open a config file."d));
        scroll.contentWidget = col;
        return scroll;
    }
    addFields(col, root, onDirty, 0);
    scroll.contentWidget = col;
    return scroll;
}

private void addFields(VerticalLayout col, ConfigNode node, void delegate() onDirty, int depth)
{
    foreach (c; node.children)
    {
        if (c.children.length)
        {
            auto h = new TextWidget(null, to!dstring((c.title.length ? c.title : c.key)));
            h.fontWeight(800).fontSize(12).margins(Rect(depth * 8, 10, 0, 4));
            col.addChild(h);
            if (c.description.length)
            {
                auto d = new TextWidget(null, to!dstring(c.description));
                d.fontSize(9).textColor(0x888888).margins(Rect(depth * 8, 0, 0, 6));
                col.addChild(d);
            }
            addFields(col, c, onDirty, depth + 1);
            continue;
        }
        col.addChild(fieldRow(c, onDirty, depth));
    }
}

private Widget fieldRow(ConfigNode n, void delegate() onDirty, int depth)
{
    auto box = new VerticalLayout();
    box.layoutWidth(FILL_PARENT).margins(Rect(depth * 8, 4, 0, 4));

    auto header = new HorizontalLayout();
    header.layoutWidth(FILL_PARENT);

    if (n.fromSchema && !n.fromFile)
    {
        auto inc = new CheckBox(null, "include"d);
        inc.checked = n.included;
        inc.click = delegate(Widget w) {
            n.included = (cast(CheckBox) w).checked;
            onDirty();
            return true;
        };
        header.addChild(inc);
    }

    auto label = n.title.length ? n.title : n.key;
    if (n.required)
        label ~= " *";
    if (!n.fromFile && n.fromSchema)
        label ~= "  (unset)";
    auto t = new TextWidget(null, to!dstring(label));
    t.fontSize(10).fontWeight(600).layoutWidth(FILL_PARENT);
    header.addChild(t);
    box.addChild(header);

    if (n.description.length)
    {
        auto d = new TextWidget(null, to!dstring(n.description));
        d.fontSize(9).textColor(0x777777).layoutWidth(FILL_PARENT);
        box.addChild(d);
    }

    if (n.schemaType == "boolean" || n.value.type == JSONType.true_
            || n.value.type == JSONType.false_)
    {
        auto cb = new CheckBox(null, ""d);
        cb.checked = displayValue(n) == "true";
        cb.click = delegate(Widget w) {
            n.included = true;
            n.fromFile = true;
            setDisplayValue(n, (cast(CheckBox) w).checked ? "true" : "false");
            onDirty();
            return true;
        };
        box.addChild(cb);
        return box;
    }

    if (n.enumValues.length)
    {
        dstring[] items;
        int sel;
        auto cur = displayValue(n);
        foreach (i, e; n.enumValues)
        {
            items ~= to!dstring(e);
            if (e == cur)
                sel = cast(int) i;
        }
        auto combo = new ComboBox(null, items);
        combo.selectedItemIndex = sel;
        combo.itemClick = delegate(Widget w, int index) {
            n.included = true;
            n.fromFile = true;
            setDisplayValue(n, n.enumValues[index]);
            onDirty();
            return true;
        };
        combo.layoutWidth(FILL_PARENT);
        box.addChild(combo);
        return box;
    }

    auto ed = new EditLine(null, to!dstring(displayValue(n)));
    ed.layoutWidth(FILL_PARENT);
    ed.contentChange = delegate(EditableContent src) {
        n.included = true;
        n.fromFile = true;
        setDisplayValue(n, to!string(ed.text));
        onDirty();
    };
    box.addChild(ed);
    return box;
}
