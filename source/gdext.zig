const std = @import("std");
pub const c = @cImport({
    @cInclude("gdextension_interface.gen.h");
});

// ---- Global state ----

pub var library: c.GDExtensionClassLibraryPtr = null;
pub var string_name_new: c.GDExtensionInterfaceStringNameNewWithLatin1Chars = null;
pub var string_new: c.GDExtensionInterfaceStringNewWithLatin1Chars = null;
pub var variant_get_ptr_destructor: c.GDExtensionInterfaceVariantGetPtrDestructor = null;
pub var string_destroy_fn: c.GDExtensionPtrDestructor = null;
pub var variant_destroy: c.GDExtensionInterfaceVariantDestroy = null;
pub var get_variant_from_type_constructor: c.GDExtensionInterfaceGetVariantFromTypeConstructor = null;
pub var get_variant_to_type_constructor: c.GDExtensionInterfaceGetVariantToTypeConstructor = null;
pub var get_ptr_utility_function: c.GDExtensionInterfaceVariantGetPtrUtilityFunction = null;
pub var print_fn: c.GDExtensionPtrUtilityFunction = null;
pub var classdb_register5: c.GDExtensionInterfaceClassdbRegisterExtensionClass5 = null;
pub var classdb_unregister: c.GDExtensionInterfaceClassdbUnregisterExtensionClass = null;
pub var classdb_register_method: c.GDExtensionInterfaceClassdbRegisterExtensionClassMethod = null;
pub var classdb_register_property: c.GDExtensionInterfaceClassdbRegisterExtensionClassProperty = null;
pub var classdb_construct_object2: c.GDExtensionInterfaceClassdbConstructObject2 = null;
pub var object_set_instance: c.GDExtensionInterfaceObjectSetInstance = null;

// ---- Init ----

pub fn init(p_get_proc_address: c.GDExtensionInterfaceGetProcAddress) bool {
    const gp = p_get_proc_address orelse return false;

    string_name_new = @ptrCast(gp("string_name_new_with_latin1_chars"));
    if (string_name_new == null) return false;
    string_new = @ptrCast(gp("string_new_with_latin1_chars"));
    if (string_new == null) return false;
    variant_get_ptr_destructor = @ptrCast(gp("variant_get_ptr_destructor"));
    if (variant_get_ptr_destructor == null) return false;
    string_destroy_fn = variant_get_ptr_destructor.?(c.GDEXTENSION_VARIANT_TYPE_STRING);
    variant_destroy = @ptrCast(gp("variant_destroy"));
    if (variant_destroy == null) return false;
    get_variant_from_type_constructor = @ptrCast(gp("get_variant_from_type_constructor"));
    if (get_variant_from_type_constructor == null) return false;
    get_variant_to_type_constructor = @ptrCast(gp("get_variant_to_type_constructor"));
    if (get_variant_to_type_constructor == null) return false;
    get_ptr_utility_function = @ptrCast(gp("variant_get_ptr_utility_function"));
    if (get_ptr_utility_function == null) return false;

    // Load Godot's print() - hash 2648703342 is stable across Godot 4.x
    var print_sn_buf = [_]u8{0} ** 16;
    string_name_new.?(@ptrCast(&print_sn_buf), "print", 1);
    print_fn = get_ptr_utility_function.?(@ptrCast(&print_sn_buf), 2648703342);

    classdb_register5 = @ptrCast(gp("classdb_register_extension_class5"));
    if (classdb_register5 == null) return false;
    classdb_unregister = @ptrCast(gp("classdb_unregister_extension_class"));
    if (classdb_unregister == null) return false;
    classdb_register_method = @ptrCast(gp("classdb_register_extension_class_method"));
    if (classdb_register_method == null) return false;
    classdb_register_property = @ptrCast(gp("classdb_register_extension_class_property"));
    if (classdb_register_property == null) return false;
    classdb_construct_object2 = @ptrCast(gp("classdb_construct_object2"));
    if (classdb_construct_object2 == null) return false;
    object_set_instance = @ptrCast(gp("object_set_instance"));
    if (object_set_instance == null) return false;

    return true;
}

// ---- String helpers ----

pub fn makeStringName(buf: *[16]u8, str: [*:0]const u8) c.GDExtensionStringNamePtr {
    @memset(buf, 0);
    const ptr: c.GDExtensionStringNamePtr = @ptrCast(buf);
    string_name_new.?(ptr, str, 1);
    return ptr;
}

pub fn makeString(buf: *[16]u8, str: [*:0]const u8) c.GDExtensionStringPtr {
    @memset(buf, 0);
    const ptr: c.GDExtensionStringPtr = @ptrCast(buf);
    string_new.?(ptr, str);
    return ptr;
}

pub fn print(msg: [*:0]const u8) void {
    var msg_buf: [16]u8 = undefined;
    const msg_str = makeString(&msg_buf, msg);
    const str_to_variant = get_variant_from_type_constructor.?(c.GDEXTENSION_VARIANT_TYPE_STRING);
    var variant_buf = [_]u8{0} ** 24;
    const variant: c.GDExtensionVariantPtr = @ptrCast(&variant_buf);
    str_to_variant.?(variant, msg_str);
    const args = [_]?*const anyopaque{variant};
    print_fn.?(null, @ptrCast(@constCast(&args)), 1);
    variant_destroy.?(variant);
    if (string_destroy_fn) |destroy| destroy(msg_str);
}

// ---- Comptime type mapping ----

pub fn zigToVariantType(comptime T: type) c.GDExtensionVariantType {
    return switch (T) {
        i64 => c.GDEXTENSION_VARIANT_TYPE_INT,
        f64 => c.GDEXTENSION_VARIANT_TYPE_FLOAT,
        bool => c.GDEXTENSION_VARIANT_TYPE_BOOL,
        else => @compileError("No GDExtension variant type for: " ++ @typeName(T)),
    };
}

pub fn zigTypeToArgMetadata(comptime T: type) c.GDExtensionClassMethodArgumentMetadata {
    return switch (T) {
        i64 => c.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64,
        f64 => c.GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE,
        else => c.GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
    };
}

pub fn variantToZig(comptime T: type, variant: c.GDExtensionConstVariantPtr) T {
    var value: T = undefined;
    const ctor = get_variant_to_type_constructor.?(zigToVariantType(T));
    ctor.?(&value, @constCast(variant));
    return value;
}

pub fn zigToVariant(comptime T: type, value: T, out: c.GDExtensionVariantPtr) void {
    var v = value;
    const ctor = get_variant_from_type_constructor.?(zigToVariantType(T));
    ctor.?(out, &v);
}
