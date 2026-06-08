const std = @import("std");
const ddp = @import("ddp-tools");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    
    const io = init.io;

    const path = "/home/roguebit/dev/translation/game/Data/sin_text.dat";
    try ddp.unpack(allocator, io, path, "extract/sin_text");
}
