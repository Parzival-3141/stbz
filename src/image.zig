const std = @import("std");

pub const Channels = enum(c_int) {
    /// Only used for `desired_channels`
    default = 0,

    grey = 1,
    grey_alpha = 2,
    rgb = 3,
    rgb_alpha = 4,
};

const root = @This();

pub const Image = struct {
    data: [*]u8,
    width: c_int,
    height: c_int,

    channels_in_data: Channels,
    channels_in_input: Channels,

    pub fn free(self: *Image) void {
        stbi_image_free(@ptrCast(*anyopaque, self.data));
        self.data = undefined;
    }

    pub fn load_from_memory(buffer: []const u8, desired_channels: Channels) !Image {
        var img: Image = undefined;
        img.data = try root.load_from_memory(buffer, &img.width, &img.height, &img.channels_in_input, desired_channels);
        img.channels_in_data = if (desired_channels == .default) img.channels_in_input else desired_channels;
        return img;
    }

    pub fn load_from_callbacks(callback: *const stbi_io_callbacks, user_data: ?*anyopaque, desired_channels: Channels) !Image {
        var img: Image = undefined;
        img.data = try root.load_from_callbacks(callback, user_data, &img.width, &img.height, &img.channels_in_input, desired_channels);
        img.channels_in_data = if (desired_channels == .default) img.channels_in_input else desired_channels;
        return img;
    }

    pub fn load(filename: [:0]const u8, desired_channels: Channels) !Image {
        var img: Image = undefined;
        img.data = try root.load(filename, &img.width, &img.height, &img.channels_in_input, desired_channels);
        img.channels_in_data = if (desired_channels == .default) img.channels_in_input else desired_channels;
        return img;
    }

    pub fn load_from_file(file: std.fs.File, allocator: std.mem.Allocator, desired_channels: Channels) !Image {
        var img: Image = undefined;
        img.data = try root.load_from_file(file, allocator, &img.width, &img.height, &img.channels_in_input, desired_channels);
        img.channels_in_data = if (desired_channels == .default) img.channels_in_input else desired_channels;
        return img;
    }
};

pub const stbi_io_callbacks = extern struct {
    /// Reads some bytes of data.
    /// Fill 'buffer' with 'count' bytes. Return number of bytes actually read.
    read: *const fn (user_data: ?*anyopaque, buffer: [*]u8, count: c_int) callconv(.C) c_int,
    /// Skips some bytes of data.
    /// Skip the next 'count' bytes, or 'unget' the last `-count` bytes if negative.
    skip: *const fn (user_data: ?*anyopaque, count: c_int) callconv(.C) void,
    /// Reports if the stream is at the end.
    /// Returns nonzero if we are at end of file/data.
    eof: *const fn (user_data: ?*anyopaque) callconv(.C) c_int,
};

pub extern fn stbi_image_free(retval_from_stbi_load: ?*anyopaque) void;

//////////////////////////////////////////////////////////////////////////////
//
// PRIMARY API - works on images of any type
//

//
// load image by filename, open file, or memory buffer
//

////////////////////////////////////
//
// 8-bits-per-channel interface
//

pub extern fn stbi_load_from_memory(buffer: [*]const u8, len: c_int, x: *c_int, y: *c_int, channels_in_file: *Channels, desired_channels: Channels) ?[*]u8;

pub fn load_from_memory(buffer: []const u8, width: *c_int, height: *c_int, channels_in_file: *Channels, desired_channels: Channels) ![*]u8 {
    std.debug.assert(buffer.len <= std.math.maxInt(c_int));
    return stbi_load_from_memory(
        buffer.ptr,
        @intCast(c_int, buffer.len),
        width,
        height,
        channels_in_file,
        desired_channels,
    ) orelse error.STB_ImageFailure;
}

pub extern fn stbi_load_from_callbacks(clbk: *const stbi_io_callbacks, user: ?*anyopaque, x: *c_int, y: *c_int, channels_in_file: *Channels, desired_channels: Channels) ?[*]u8;

pub fn load_from_callbacks(callback: *const stbi_io_callbacks, user_data: ?*anyopaque, width: *c_int, height: *c_int, channels_in_file: *Channels, desired_channels: Channels) ![*]u8 {
    return stbi_load_from_callbacks(
        callback,
        user_data,
        width,
        height,
        channels_in_file,
        desired_channels,
    ) orelse error.STB_ImageFailure;
}

// @Todo: support cDefine configuration somehow...
// #ifndef STBI_NO_STDIO
pub extern fn stbi_load(filename: [*:0]const u8, x: *c_int, y: *c_int, channels_in_file: *Channels, desired_channels: Channels) ?[*]u8;

pub fn load(filename: [:0]const u8, width: *c_int, height: *c_int, channels_in_file: *Channels, desired_channels: Channels) ![*]u8 {
    return stbi_load(
        filename,
        width,
        height,
        channels_in_file,
        desired_channels,
    ) orelse error.STB_ImageFailure;
}

/// File pointer is left pointing immediately after image.
pub extern fn stbi_load_from_file(f: *std.c.FILE, x: *c_int, y: *c_int, channels_in_file: *Channels, desired_channels: Channels) ?[*]u8;

/// If you're looking for the `load_from_file()` that takes a `std.c.FILE`, use `stbi_load_from_file()`
pub fn load_from_file(file: std.fs.File, allocator: std.mem.Allocator, width: *c_int, height: *c_int, channels_in_file: *Channels, desired_channels: Channels) ![*]u8 {
    const contents = try file.readToEndAlloc(allocator, std.math.maxInt(c_int));
    defer allocator.free(contents);
    return try load_from_memory(contents, width, height, channels_in_file, desired_channels);
}
// #endif

// #ifndef STBI_NO_GIF
/// `channels_in_file` always reports as 4-channel
pub extern fn stbi_load_gif_from_memory(buffer: [*]const u8, len: c_int, delays: *[*]c_int, x: *c_int, y: *c_int, z: *c_int, channels_in_file: *Channels, desired_channels: Channels) ?[*]u8;
/// `channels_in_file` always reports as 4-channel
// pub fn load_gif_from_memory(buffer: []const u8, delays: *[*]c_int, x: *c_int, y: *c_int, z: *c_int, channels_in_file: *Channels, desired_channels: Channels) ![*]u8 {}
// #endif

// #ifdef STBI_WINDOWS_UTF8
/// convert Windows wchar_t filenames to utf8.
pub extern fn stbi_convert_wchar_to_utf8(buffer: [*]u8, buffer_len: usize, input: [*:0]const u16) c_int;
pub fn convert_wchar_to_utf8(buffer: []u8, input: [*:0]const u16) c_int {
    return stbi_convert_wchar_to_utf8(buffer.ptr, buffer.len, input);
}
// #endif

extern fn stbi_set_flip_vertically_on_load(flag_true_if_should_flip: c_int) void;

/// Global setting. Flips images vertically, so the first pixel in the output array is the bottom left
pub fn flip_vertically_on_load(should_flip: bool) void {
    stbi_set_flip_vertically_on_load(@boolToInt(should_flip));
}

test "load_from_memory" {
    const test_image = @embedFile("test.png");
    {
        var w: c_int = undefined;
        var h: c_int = undefined;
        var channels: Channels = undefined;
        const result = try load_from_memory(test_image, &w, &h, &channels, .rgb);
        defer stbi_image_free(result);

        try run_test(w, h, channels);
    }

    {
        var img = try Image.load_from_memory(test_image, .rgb);
        defer img.free();
        try run_img_test(img);
    }
}

test "load_from_callbacks" {
    const Stream = struct {
        index: usize,
        data: []const u8,

        pub fn read(data: ?*anyopaque, out: [*c]u8, count: c_int) callconv(.C) c_int {
            const self = opaque_to_self(data);

            const bytes_left = self.data.len - self.index;
            const bytes_read = @min(@intCast(usize, count), bytes_left);

            for (out, self.data[self.index .. self.index + bytes_read]) |*d, s| d.* = s;
            self.index += bytes_read;

            return @intCast(c_int, bytes_read);
        }

        pub fn skip(data: ?*anyopaque, count: c_int) callconv(.C) void {
            const self = opaque_to_self(data);

            if (std.math.sign(count) == -1) {
                const sub = @subWithOverflow(self.index, std.math.absCast(count));
                self.index = if (sub[1] != 0) 0 else sub[0];
            } else {
                const add = @addWithOverflow(self.index, std.math.absCast(count));
                self.index = if (add[1] != 0) std.math.maxInt(usize) else add[0];
            }
        }

        pub fn eof(data: ?*anyopaque) callconv(.C) c_int {
            const self = opaque_to_self(data);
            return @boolToInt(self.index >= self.data.len);
        }

        // @Todo: this kinda sucks. Maybe have a typed wrapper for the io callbacks?
        fn opaque_to_self(data: ?*anyopaque) *@This() {
            return @ptrCast(*@This(), @alignCast(@alignOf(*@This()), data));
        }
    };

    {
        const callback = stbi_io_callbacks{
            .read = Stream.read,
            .skip = Stream.skip,
            .eof = Stream.eof,
        };

        var stream = Stream{ .index = 0, .data = @embedFile("test.png") };

        var w: c_int = undefined;
        var h: c_int = undefined;
        var channels: Channels = undefined;
        const result = try load_from_callbacks(&callback, &stream, &w, &h, &channels, .rgb);
        defer stbi_image_free(result);

        try run_test(w, h, channels);
    }

    // const TestStream = opaque {
    //     pub const Context = struct {
    //         index: usize,
    //         data: []const u8,
    //     };

    //     pub fn init(data: []const u8) Context {
    //         return Context{ .index = 0, .data = data };
    //     }

    //     pub fn read(self: ?*anyopaque, out: [*]u8, count: c_int) callconv(.C) c_int {
    //         const ctx = @ptrCast(*Context, self);

    //         const bytes_left = ctx.data.len - ctx.index;
    //         const bytes_read = @min(@intCast(usize, count), bytes_left);

    //         for (out, ctx.data[ctx.index .. ctx.index + bytes_read]) |*d, s| d.* = s;
    //         ctx.index += bytes_read;

    //         return @intCast(c_int, bytes_read);
    //     }

    //     pub fn skip(self: ?*anyopaque, count: c_int) callconv(.C) void {
    //         const ctx = @ptrCast(*Context, self);

    //         if (std.math.sign(count) == -1) {
    //             const sub = @subWithOverflow(ctx.index, std.math.absCast(count));
    //             ctx.index = if (sub[1] != 0) 0 else sub[0];
    //         } else {
    //             const add = @addWithOverflow(ctx.index, std.math.absCast(count));
    //             ctx.index = if (add[1] != 0) std.math.maxInt(usize) else add[0];
    //         }
    //     }

    //     pub fn eof(self: ?*anyopaque) callconv(.C) c_int {
    //         const ctx = @ptrCast(*Context, self);
    //         return @boolToInt(ctx.index >= ctx.data.len);
    //     }
    // };

    {
        const callback = stbi_io_callbacks{
            .read = Stream.read,
            .skip = Stream.skip,
            .eof = Stream.eof,
        };

        var stream = Stream{ .index = 0, .data = @embedFile("test.png") };
        // var stream = TestStream.init(@embedFile("test.png"));

        var img = try Image.load_from_callbacks(&callback, &stream, .rgb);
        defer img.free();
        try run_img_test(img);
    }
}

// !Warning! this test will fail if the cwd isn't the project root!
test "load" {
    {
        var w: c_int = undefined;
        var h: c_int = undefined;
        var channels: Channels = undefined;
        const result = try load("src/test.png", &w, &h, &channels, .rgb);
        defer stbi_image_free(result);

        try run_test(w, h, channels);
    }

    {
        var img = try Image.load("src/test.png", .rgb);
        defer img.free();
        try run_img_test(img);
    }
}

// !Warning! this test will fail if the cwd isn't the project root!
test "load_from_file" {
    const file = try std.fs.cwd().openFile("src/test.png", .{});
    defer file.close();

    {
        var w: c_int = undefined;
        var h: c_int = undefined;
        var channels: Channels = undefined;
        const result = try load_from_file(file, std.testing.allocator, &w, &h, &channels, .rgb);
        defer stbi_image_free(result);

        try run_test(w, h, channels);
    }

    try file.seekTo(0);

    {
        var img = try Image.load_from_file(file, std.testing.allocator, .rgb);
        defer img.free();
        try run_img_test(img);
    }
}

test "flip_vertically" {
    flip_vertically_on_load(true);

    var img = try Image.load_from_memory(@embedFile("test.png"), .rgb);
    defer img.free();

    try run_img_test(img);
}

fn run_img_test(img: Image) !void {
    try run_test(img.width, img.height, img.channels_in_input);
    try std.testing.expectEqual(Channels.rgb, img.channels_in_data);
}

fn run_test(w: c_int, h: c_int, channels: Channels) !void {
    try std.testing.expect(w == 402);
    try std.testing.expect(h == 573);
    try std.testing.expectEqual(Channels.rgb_alpha, channels);
}
