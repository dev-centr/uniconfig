module uniconfig.app.dui_host;

import std.stdio;
import dew;
import dui;
import uniconfig.app.session;
import uniconfig.app.panel_ui;
import uniconfig.app.dui_callbacks : safeBuilder;
import uniconfig.app.versioninfo;

void bindSessionStates(ref DuiApp app, ref PanelSession s) @safe
{
    app.bind(s.tick);
    app.bind(s.status);
    app.bind(s.pathInput);
}

/// One SoftwareBackend frame — CI smoke without GLFW/Vello.
void runHeadlessPanel(ref PanelSession s) @safe
{
    DuiApp app;
    bindSessionStates(app, s);
    app.init(safeBuilder((ref UiBuilder ui) { return buildPanelRoot(s); }), new SoftwareBackend(1100, 720));
    app.dew.resize(1100, 720);
    app.frame();
    writeln("headless OK; registry=", s.registry.files.length);
}

version (ConfigUIWindowed)
{
    import glfw3.api;

    version (Windows)
    {
        import core.sys.windows.windows;
        extern (C) HWND glfwGetWin32Window(GLFWwindow* window);
    }
    else version (linux)
    {
        extern (C) void* glfwGetX11Display();
        extern (C) ulong glfwGetX11Window(GLFWwindow* window);
    }

    bool attachVelloBackend(VelloRenderBackend gpu, GLFWwindow* window, uint w, uint h) @trusted
    {
        version (Windows)
        {
            HWND hwnd = glfwGetWin32Window(window);
            HINSTANCE hinstance = GetModuleHandleA(null);
            gpu.attach(cast(void*) hwnd, cast(void*) hinstance, w, h);
            return gpu.attached;
        }
        else version (linux)
        {
            auto xDisp = glfwGetX11Display();
            auto xWin = glfwGetX11Window(window);
            if (xDisp !is null && xWin != 0)
            {
                gpu.attachX11(xDisp, xWin, 0, w, h);
                return gpu.attached;
            }
            return false;
        }
        else
            return false;
    }

    void runWindowedPanel(ref PanelSession s) @trusted
    {
        if (!glfwInit())
        {
            stderr.writeln("glfwInit failed");
            return;
        }
        scope (exit)
            glfwTerminate();

        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        enum int winW = 1100;
        enum int winH = 720;
        auto window = glfwCreateWindow(winW, winH, appDisplayName.ptr, null, null);
        if (window is null)
        {
            stderr.writeln("glfwCreateWindow failed");
            return;
        }
        scope (exit)
            glfwDestroyWindow(window);

        auto gpu = new VelloRenderBackend();
        if (!attachVelloBackend(gpu, window, winW, winH))
        {
            stderr.writeln("Vello attach failed (GPU surface unavailable on this platform).");
            return;
        }
        scope (exit)
            gpu.shutdown();

        DuiApp app;
        bindSessionStates(app, s);
        app.init(safeBuilder((ref UiBuilder ui) { return buildPanelRoot(s); }), gpu);

        extern (C) void scaleThunk(void* win, float* sx, float* sy) nothrow @nogc
        {
            glfwGetWindowContentScale(cast(GLFWwindow*) win, sx, sy);
        }

        {
            int fbW, fbH;
            glfwGetFramebufferSize(window, &fbW, &fbH);
            auto scale = contentScaleFromGlfw(cast(void*) window, cast(GlfwContentScaleFn) &scaleThunk);
            app.dew.syncFromFramebuffer(fbW, fbH, scale);
        }
        app.frame();

        bool mouseWasDown;
        while (!glfwWindowShouldClose(window))
        {
            glfwPollEvents();
            int fbW, fbH;
            glfwGetFramebufferSize(window, &fbW, &fbH);
            float sx, sy;
            glfwGetWindowContentScale(window, &sx, &sy);
            app.dew.syncFromFramebuffer(fbW, fbH, ScaleFactor(sx, sy));

            double mx, my;
            glfwGetCursorPos(window, &mx, &my);
            const down = glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS;
            if (down != mouseWasDown)
            {
                PointerEvent ev;
                ev.x = cast(float) mx;
                ev.y = cast(float) my;
                ev.kind = PointerKind.Mouse;
                ev.phase = down ? PointerPhase.Down : PointerPhase.Up;
                ev.button = PointerButton.Left;
                ev.pressed = down;
                ev.primary = true;
                app.pointer(ev);
                app.requestRebuild();
            }
            else if (down)
            {
                PointerEvent ev;
                ev.x = cast(float) mx;
                ev.y = cast(float) my;
                ev.kind = PointerKind.Mouse;
                ev.phase = PointerPhase.Move;
                ev.button = PointerButton.Left;
                ev.pressed = true;
                ev.primary = true;
                app.pointer(ev);
            }
            mouseWasDown = down;

            pollWindowKeys(app, s, window);
            app.frame();
        }
    }

    void pollWindowKeys(ref DuiApp app, ref PanelSession s, GLFWwindow* window) @trusted
    {
        void edge(string key, int gk)
        {
            static bool[512] was;
            const down = glfwGetKey(window, gk) == GLFW_PRESS;
            const idx = gk & 511;
            if (down && !was[idx])
            {
                KeyEvent ev;
                ev.key = key;
                ev.phase = KeyPhase.Down;
                ev.ctrl = glfwGetKey(window, GLFW_KEY_LEFT_CONTROL) == GLFW_PRESS
                    || glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL) == GLFW_PRESS;
                ev.shift = glfwGetKey(window, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS
                    || glfwGetKey(window, GLFW_KEY_RIGHT_SHIFT) == GLFW_PRESS;
                app.key(ev);
                app.requestRebuild();
            }
            was[idx] = down;
        }

        edge("Backspace", GLFW_KEY_BACKSPACE);
        edge("Enter", GLFW_KEY_ENTER);
        edge("Tab", GLFW_KEY_TAB);
        edge("s", GLFW_KEY_S);

        static bool saveWas;
        const ctrlDown = glfwGetKey(window, GLFW_KEY_LEFT_CONTROL) == GLFW_PRESS
            || glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL) == GLFW_PRESS;
        const sDown = glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS;
        if (ctrlDown && sDown && !saveWas)
        {
            import uniconfig.app.document_ops : saveDocumentCurrent;
            saveDocumentCurrent(s);
        }
        saveWas = ctrlDown && sDown;

        if (ctrlDown)
            return;

        foreach (int code; 'A' .. 'Z' + 1)
        {
            auto gk = GLFW_KEY_A + (code - 'A');
            static bool[26] letterWas;
            const i = code - 'A';
            const down = glfwGetKey(window, gk) == GLFW_PRESS;
            if (down && !letterWas[i])
            {
                const shift = glfwGetKey(window, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS
                    || glfwGetKey(window, GLFW_KEY_RIGHT_SHIFT) == GLFW_PRESS;
                char ch = cast(char)(shift ? code : code + 32);
                KeyEvent ev;
                ev.key = [ch].idup;
                ev.phase = KeyPhase.Down;
                app.key(ev);
                app.requestRebuild();
            }
            letterWas[i] = down;
        }
        {
            static bool spaceWas;
            const down = glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_PRESS;
            if (down && !spaceWas)
            {
                KeyEvent ev;
                ev.key = " ";
                ev.phase = KeyPhase.Down;
                app.key(ev);
                app.requestRebuild();
            }
            spaceWas = down;
        }
    }
}
else
{
    void runWindowedPanel(ref PanelSession s) @trusted
    {
        stderr.writeln("Build with -c windowed for the GLFW UI.");
        runHeadlessPanel(s);
    }
}
