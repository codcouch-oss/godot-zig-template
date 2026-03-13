const gdext = @import("gdext.zig");
const register = @import("register.zig");

pub const HelloNode = struct {
    greeting_count: i64 = 0,

    pub const godot_name = "HelloNodeZig";
    pub const godot_base = "Node";

    pub const godot_methods = [_][:0]const u8{
        "say_hello",
        "get_greeting_count",
        "set_greeting_count",
    };

    pub const godot_properties = [_]register.GodotProperty{
        .{ .name = "greeting_count", .getter = "get_greeting_count", .setter = "set_greeting_count" },
    };

    pub fn say_hello(self: *@This()) void {
        _ = self;
        gdext.print("Hello from Zig!");
    }

    pub fn get_greeting_count(self: *@This()) i64 {
        return self.greeting_count;
    }

    pub fn set_greeting_count(self: *@This(), value: i64) void {
        self.greeting_count = value;
    }
};
