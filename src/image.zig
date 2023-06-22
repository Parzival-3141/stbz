const std = @import("std");
const c = @import("c.zig");

pub const Channels = enum(c_int) {
    /// Only used for `desired_channels`
    default = 0,

    grey = 1,
    grey_alpha = 2,
    rgb = 3,
    rgb_alpha = 4,
};

pub const Image = struct {
    data: [*]u8,
    width: c_int,
    height: c_int,

    channels_in_data: Channels,
    channels_in_input: Channels,

    pub fn free(self: *Image) void {
        c.stbi_image_free(@ptrCast(*anyopaque, self.data));
        self.data = undefined;
    }
};

//////////////////////////////////////////////////////////////////////////////
//
// PRIMARY API - works on images of any type
//

//
// load image by filename, open file, or memory buffer
//

pub const IO_Callbacks = struct {
    /// Reads some bytes of data.
    /// Fill 'buffer' with 'count' bytes. Return number of bytes actually read.
    read: ReadFn,
    /// Skips some bytes of data.
    /// Skip the next 'count' bytes, or 'unget' the last `-count` bytes if negative.
    skip: SkipFn,
    /// Reports if the stream is at the end.
    /// Returns nonzero if we are at end of file/data.
    eof: EofFn,

    pub const ReadFn = fn (callback_data: *anyopaque, buffer: [*]u8, count: c_int) callconv(.C) c_int;
    pub const SkipFn = fn (callback_data: *anyopaque, count: c_int) callconv(.C) *anyopaque;
    pub const EofFn = fn (callback_data: *anyopaque) callconv(.C) c_int;
};

////////////////////////////////////
//
// 8-bits-per-channel interface
//

pub fn load_from_memory(buffer: []const u8, width: *c_int, height: *c_int, channels_in_file: *Channels, desired_channels: Channels) ![*]u8 {
    std.debug.assert(buffer.len <= std.math.maxInt(c_int));

    return c.stbi_load_from_memory(
        buffer.ptr,
        @intCast(c_int, buffer.len),
        width,
        height,
        @ptrCast(*c_int, channels_in_file),
        @enumToInt(desired_channels),
    ) orelse error.STB_ImageFailure;
}
// @Todo: figure out if I'm gonna use this API style (spoiler: I probably will)
pub fn load_img_from_memory(buffer: []const u8, img: *Image, desired_channels: Channels) !void {
    std.debug.assert(buffer.len <= std.math.maxInt(c_int));

    const data = c.stbi_load_from_memory(
        buffer.ptr,
        @intCast(c_int, buffer.len),
        &img.width,
        &img.height,
        @ptrCast(*c_int, &img.channels_in_input),
        @enumToInt(desired_channels),
    ) orelse return error.STB_ImageFailure;

    img.channels_in_data = if (desired_channels == .default) img.channels_in_input else desired_channels;
    img.data = data;
}

pub fn load_from_callbacks(callback: *IO_Callbacks, user_data: ?*anyopaque, width: *c_int, height: *c_int, channels_in_file: *Channels, desired_channels: Channels) [*]u8 {
    _ = desired_channels;
    _ = channels_in_file;
    _ = height;
    _ = width;
    _ = user_data;
    _ = callback;
}

// #ifndef STBI_NO_STDIO
pub fn load(filename: []const u8, width: *c_int, height: *c_int, channels_in_file: *Channels, desired_channels: Channels) [*]u8 {
    _ = desired_channels;
    _ = channels_in_file;
    _ = height;
    _ = width;
    _ = filename;
}

/// File pointer is left pointing immediately after image.
pub fn load_from_cfile(file: *std.c.FILE, width: *c_int, height: *c_int, channels_in_file: *Channels, desired_channels: Channels) [*]u8 {
    _ = desired_channels;
    _ = channels_in_file;
    _ = height;
    _ = width;
    _ = file;
}
// #endif

// #ifndef STBI_NO_GIF
// /// (*comp always reports as 4-channel)
// pub fn load_gif_from_memory(buffer: []const u8, delays: **c_int, x: [*c]c_int, y: [*c]c_int, z: [*c]c_int, comp: [*c]c_int, req_comp: c_int) [*c]stbi_uc;
// #endif

// #ifdef STBI_WINDOWS_UTF8
// STBIDEF int stbi_convert_wchar_to_utf8(char *buffer, size_t bufferlen, const wchar_t* input);
// #endif

test "load_from_memory" {
    const test_image = @embedFile("test.png");
    {
        var w: c_int = undefined;
        var h: c_int = undefined;
        var channels: Channels = undefined;
        const result = try load_from_memory(test_image, &w, &h, &channels, .rgb);
        defer c.stbi_image_free(result);

        try std.testing.expect(w == 402);
        try std.testing.expect(h == 573);
        try std.testing.expectEqual(Channels.rgb_alpha, channels);
    }

    {
        var img: Image = undefined;
        try load_img_from_memory(test_image, &img, .rgb);
        defer img.free();

        try std.testing.expect(img.width == 402);
        try std.testing.expect(img.height == 573);
        try std.testing.expectEqual(Channels.rgb, img.channels_in_data);
        try std.testing.expectEqual(Channels.rgb_alpha, img.channels_in_input);
    }
}
