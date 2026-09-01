module uniconfig.app.dui_callbacks;

import dew;
import dui;

void delegate() @safe safeClick(void delegate() @system fn) @trusted
{
    return cast(void delegate() @safe) fn;
}

Widget delegate(ref UiBuilder ui) @safe safeBuilder(Widget delegate(ref UiBuilder ui) @system fn) @trusted
{
    return cast(Widget delegate(ref UiBuilder ui) @safe) fn;
}
