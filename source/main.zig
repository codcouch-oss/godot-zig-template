const gdext = @import("gdext.zig");
const register = @import("register.zig");
const HelloNode = @import("hello_node.zig").HelloNode;

const c = gdext.c;

fn initializeExtension(_: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.c) void {
    if (p_level != c.GDEXTENSION_INITIALIZATION_SCENE) return;
    register.registerClass(HelloNode);
}

fn deinitializeExtension(_: ?*anyopaque, p_level: c.GDExtensionInitializationLevel) callconv(.c) void {
    if (p_level != c.GDEXTENSION_INITIALIZATION_SCENE) return;
    register.unregisterClass(HelloNode);
}

export fn extension_init(
    p_get_proc_address: c.GDExtensionInterfaceGetProcAddress,
    p_library: c.GDExtensionClassLibraryPtr,
    r_initialization: [*c]c.GDExtensionInitialization,
) c.GDExtensionBool {
    gdext.library = p_library;
    if (!gdext.init(p_get_proc_address)) return 0;

    r_initialization.*.minimum_initialization_level = c.GDEXTENSION_INITIALIZATION_SCENE;
    r_initialization.*.userdata = null;
    r_initialization.*.initialize = initializeExtension;
    r_initialization.*.deinitialize = deinitializeExtension;
    return 1;
}
