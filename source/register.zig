//! Comptime Godot class registration.
//!
//! Usage: define a struct with these comptime decls, then call registerClass(T):
//!
//!   pub const godot_name = "MyClass";           // Godot class name
//!   pub const godot_base = "Node";              // Godot base class
//!   pub const godot_methods = [_][:0]const u8{ "my_method" };
//!   pub const godot_properties = [_]GodotProperty{
//!       .{ .name = "count", .getter = "get_count", .setter = "set_count" },
//!   };
//!
//! Methods receive *T as their first argument (self). Supported parameter/return
//! types: i64, f64, bool, void.

const std = @import("std");
const gdext = @import("gdext.zig");
const c = gdext.c;

pub const GodotProperty = struct {
    name: [:0]const u8,
    getter: [:0]const u8,
    setter: [:0]const u8,
};

// Internal wrapper so we can store godot_object alongside user data and
// recover the allocation pointer in the free callback.
fn InstanceWrapper(comptime T: type) type {
    return struct {
        godot_object: c.GDExtensionObjectPtr,
        data: T,
    };
}

pub fn registerClass(comptime T: type) void {
    comptime {
        if (!@hasDecl(T, "godot_name")) @compileError(@typeName(T) ++ " must declare pub const godot_name");
        if (!@hasDecl(T, "godot_base")) @compileError(@typeName(T) ++ " must declare pub const godot_base");
    }

    const Wrapper = InstanceWrapper(T);

    // Generate lifecycle callbacks capturing T at comptime.
    const Cbs = struct {
        fn create(_: ?*anyopaque, _: c.GDExtensionBool) callconv(.c) c.GDExtensionObjectPtr {
            const inst = std.heap.c_allocator.create(Wrapper) catch return null;
            inst.* = .{ .godot_object = null, .data = std.mem.zeroes(T) };
            var base_buf: [16]u8 = undefined;
            inst.godot_object = gdext.classdb_construct_object2.?(gdext.makeStringName(&base_buf, T.godot_base));
            var class_buf: [16]u8 = undefined;
            gdext.object_set_instance.?(inst.godot_object, gdext.makeStringName(&class_buf, T.godot_name), @ptrCast(&inst.data));
            return inst.godot_object;
        }

        fn free(_: ?*anyopaque, p_instance: c.GDExtensionClassInstancePtr) callconv(.c) void {
            const data: *T = @ptrCast(@alignCast(p_instance));
            const inst: *Wrapper = @fieldParentPtr("data", data);
            std.heap.c_allocator.destroy(inst);
        }

        fn set(_: c.GDExtensionClassInstancePtr, _: c.GDExtensionConstStringNamePtr, _: c.GDExtensionConstVariantPtr) callconv(.c) c.GDExtensionBool {
            return 0;
        }
        fn get(_: c.GDExtensionClassInstancePtr, _: c.GDExtensionConstStringNamePtr, _: c.GDExtensionVariantPtr) callconv(.c) c.GDExtensionBool {
            return 0;
        }
        fn notification(_: c.GDExtensionClassInstancePtr, _: i32, _: c.GDExtensionBool) callconv(.c) void {}
    };

    var class_buf: [16]u8 = undefined;
    var parent_buf: [16]u8 = undefined;
    const class_sn = gdext.makeStringName(&class_buf, T.godot_name);
    const parent_sn = gdext.makeStringName(&parent_buf, T.godot_base);

    var info = std.mem.zeroes(c.GDExtensionClassCreationInfo5);
    info.is_exposed = 1;
    info.set_func = Cbs.set;
    info.get_func = Cbs.get;
    info.notification_func = Cbs.notification;
    info.create_instance_func = Cbs.create;
    info.free_instance_func = Cbs.free;
    gdext.classdb_register5.?(gdext.library, class_sn, parent_sn, &info);

    if (@hasDecl(T, "godot_methods")) {
        inline for (T.godot_methods) |method_name| {
            registerMethod(T, method_name, class_sn);
        }
    }

    if (@hasDecl(T, "godot_properties")) {
        inline for (T.godot_properties) |prop| {
            registerProperty(T, prop, class_sn);
        }
    }
}

pub fn unregisterClass(comptime T: type) void {
    var class_buf: [16]u8 = undefined;
    gdext.classdb_unregister.?(gdext.library, gdext.makeStringName(&class_buf, T.godot_name));
}

// Generates a C-callable wrapper for a Zig method. Unpacks Variants into
// native Zig types, calls the method, and packs the return value back.
fn makeCallFunc(comptime T: type, comptime func: anytype) c.GDExtensionClassMethodCall {
    return struct {
        fn call(
            _: ?*anyopaque,
            p_instance: c.GDExtensionClassInstancePtr,
            p_args: [*c]const c.GDExtensionConstVariantPtr,
            _: c.GDExtensionInt,
            r_return: c.GDExtensionVariantPtr,
            r_error: [*c]c.GDExtensionCallError,
        ) callconv(.c) void {
            const Fn = @TypeOf(func);
            const fn_info = @typeInfo(Fn).@"fn";
            const RetType = fn_info.return_type orelse void;
            const params = fn_info.params;

            r_error.*.@"error" = c.GDEXTENSION_CALL_OK;

            const self: *T = @ptrCast(@alignCast(p_instance));
            var call_args: std.meta.ArgsTuple(Fn) = undefined;
            call_args[0] = self;
            inline for (1..params.len) |i| {
                call_args[i] = gdext.variantToZig(params[i].type.?, p_args[i - 1]);
            }

            if (RetType == void) {
                @call(.auto, func, call_args);
            } else {
                gdext.zigToVariant(RetType, @call(.auto, func, call_args), r_return);
            }
        }
    }.call;
}

fn registerMethod(comptime T: type, comptime name: [:0]const u8, class_sn: c.GDExtensionStringNamePtr) void {
    const func = @field(T, name);
    const Fn = @TypeOf(func);
    const fn_info = @typeInfo(Fn).@"fn";
    const RetType = fn_info.return_type orelse void;
    const params = fn_info.params;
    const arg_count = params.len - 1; // subtract self

    var m = std.mem.zeroes(c.GDExtensionClassMethodInfo);
    var name_buf: [16]u8 = undefined;
    m.name = gdext.makeStringName(&name_buf, name);
    m.call_func = makeCallFunc(T, func);
    m.method_flags = c.GDEXTENSION_METHOD_FLAGS_DEFAULT;
    m.has_return_value = if (RetType == void) 0 else 1;

    // Return value metadata
    var ret_info: c.GDExtensionPropertyInfo = undefined;
    var ret_name_buf: [16]u8 = undefined;
    var ret_class_buf: [16]u8 = undefined;
    var ret_hint_buf: [16]u8 = undefined;
    if (RetType != void) {
        ret_info = std.mem.zeroes(c.GDExtensionPropertyInfo);
        ret_info.type = gdext.zigToVariantType(RetType);
        ret_info.name = gdext.makeStringName(&ret_name_buf, "");
        ret_info.class_name = gdext.makeStringName(&ret_class_buf, "");
        ret_info.hint_string = gdext.makeString(&ret_hint_buf, "");
        ret_info.usage = 6;
        m.return_value_info = &ret_info;
        m.return_value_metadata = gdext.zigTypeToArgMetadata(RetType);
    }

    // Argument metadata — arrays are comptime-sized, stack-allocated
    var args_info: [arg_count]c.GDExtensionPropertyInfo = undefined;
    var args_meta: [arg_count]c.GDExtensionClassMethodArgumentMetadata = undefined;
    var arg_name_bufs: [arg_count][16]u8 = undefined;
    var arg_class_bufs: [arg_count][16]u8 = undefined;
    var arg_hint_bufs: [arg_count][16]u8 = undefined;
    inline for (0..arg_count) |i| {
        const ArgT = params[i + 1].type.?;
        args_info[i] = std.mem.zeroes(c.GDExtensionPropertyInfo);
        args_info[i].type = gdext.zigToVariantType(ArgT);
        args_info[i].name = gdext.makeStringName(&arg_name_bufs[i], "");
        args_info[i].class_name = gdext.makeStringName(&arg_class_bufs[i], "");
        args_info[i].hint_string = gdext.makeString(&arg_hint_bufs[i], "");
        args_info[i].usage = 6;
        args_meta[i] = gdext.zigTypeToArgMetadata(ArgT);
    }
    if (arg_count > 0) {
        m.argument_count = @intCast(arg_count);
        m.arguments_info = &args_info[0];
        m.arguments_metadata = &args_meta[0];
    }

    gdext.classdb_register_method.?(gdext.library, class_sn, &m);
}

fn registerProperty(comptime T: type, comptime prop: GodotProperty, class_sn: c.GDExtensionStringNamePtr) void {
    // Infer the property's variant type from its getter's return type.
    const getter_ret = @typeInfo(@TypeOf(@field(T, prop.getter))).@"fn".return_type.?;

    var prop_name_buf: [16]u8 = undefined;
    var prop_class_buf: [16]u8 = undefined;
    var prop_hint_buf: [16]u8 = undefined;
    var prop_info = std.mem.zeroes(c.GDExtensionPropertyInfo);
    prop_info.type = gdext.zigToVariantType(getter_ret);
    prop_info.name = gdext.makeStringName(&prop_name_buf, prop.name);
    prop_info.class_name = gdext.makeStringName(&prop_class_buf, "");
    prop_info.hint_string = gdext.makeString(&prop_hint_buf, "");
    prop_info.usage = 6;

    var setter_buf: [16]u8 = undefined;
    var getter_buf: [16]u8 = undefined;
    gdext.classdb_register_property.?(
        gdext.library,
        class_sn,
        &prop_info,
        gdext.makeStringName(&setter_buf, prop.setter),
        gdext.makeStringName(&getter_buf, prop.getter),
    );
}
