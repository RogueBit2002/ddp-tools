const std = @import("std");
const c = @import("c");

pub const DDPError = error{
    InvalidFormat,
    FileError
};

const Header = struct {
    magic: u32,
    entries: u32,
    offset: u32,

    pub fn fromReader(reader: *std.Io.Reader, endian: std.builtin.Endian) !Header {
        const header = Header{
            .magic = try reader.takeInt(u32, endian),
            .entries = try reader.takeInt(u32, endian),
            .offset = try reader.takeInt(u32, endian),
        };

        reader.toss(20);

        return header;
    }
};

const DDP3_L1_Entry = struct {
    size: u32,
    offset: u32,

    pub fn fromReader(reader: *std.Io.Reader, endian: std.builtin.Endian) !DDP3_L1_Entry {
        return DDP3_L1_Entry {
            .size = try reader.takeInt(u32, endian),
            .offset = try reader.takeInt(u32, endian)
        };
    }
};

const DDP3_L2_Entry = struct {
    size: u8,
    offset: u32,
    compressed_size: u32,
    uncompressed_size: u32,

    pub fn fromReader(reader: *std.Io.Reader, endian: std.builtin.Endian) !DDP3_L2_Entry {
        const entry: DDP3_L2_Entry = DDP3_L2_Entry{

            .size = try reader.takeByte(),
            .offset = try reader.takeInt(u32, endian),
            .uncompressed_size = try reader.takeInt(u32, endian),
            .compressed_size = try reader.takeInt(u32, endian)
        };

        reader.toss(4);

        return entry;
    }

    pub fn nameLength(entry: DDP3_L2_Entry) u8 {
        return entry.size - 17;
    }
};

pub fn unpack(allocator: std.mem.Allocator, io: std.Io, path: []const u8, destination: []const u8) !void {    
    const cwd = std.Io.Dir.cwd();

    const out_dir = try cwd.createDirPathOpen(io, destination, .{});

    defer out_dir.close(io);
    const source_file: std.Io.File = cwd.openFile(io, path, .{ .allow_directory = false }) catch return DDPError.FileError;
    defer source_file.close(io); 

    const stat = source_file.stat(io) catch return DDPError.FileError;

    if(stat.size > std.math.maxInt(u32)) 
        return DDPError.InvalidFormat;

    if(stat.size < 22)
        return DDPError.InvalidFormat;

    var buffer: [4096]u8 = undefined;
    var reader = source_file.reader(io, &buffer);

    // File uses little endian format
    const header = Header.fromReader(&reader.interface, .little) catch return DDPError.InvalidFormat;
    
    // Reader is now at 0x20; the beginning of the index
    // Will process everything depth first
    
    for(0..header.entries) |i| {
        _ = &reader.seekTo(0x20 + i*8);
        
        const l1_entry = DDP3_L1_Entry.fromReader(&reader.interface, .little) catch return DDPError.InvalidFormat;
        
        if(l1_entry.size == 0)
            continue;

        _ = &reader.seekTo(l1_entry.offset);

        var getsize: u32 = 0;
   
        while(getsize < l1_entry.size - 1) {
            const l2_entry = DDP3_L2_Entry.fromReader(&reader.interface, .little) catch return DDPError.InvalidFormat;

            const name16 = allocator.alloc(u16, l2_entry.nameLength()/2 - 1) catch unreachable;

            for(0..name16.len) |j| {
                name16[j] = reader.interface.takeInt(u16, .little) catch unreachable;
            }

            reader.interface.toss(2); // Remove last ZERO utf16

            const name = std.unicode.utf16LeToUtf8Alloc(allocator, name16) catch unreachable;
            defer allocator.free(name);
            allocator.free(name16); // Might as well free it now
      
            std.debug.print("Unpacking {s}\n", .{ name });
            const out_file = try out_dir.createFile(io, name, .{ .truncate = true });
            defer out_file.close(io);

            const pos: u32 = @truncate(reader.logicalPos());

            _ = &reader.seekTo(l2_entry.offset);
        
            const uncompressed_data = try allocator.alloc(u8, l2_entry.uncompressed_size);
            defer allocator.free(uncompressed_data);
            
            if(l2_entry.compressed_size == 0) {
                for(0..uncompressed_data.len) |j| {
                    uncompressed_data[j] = try reader.interface.takeByte();
                }
            } else {
                const compressed_data = try allocator.alloc(u8, l2_entry.compressed_size);
                defer allocator.free(compressed_data);

                for(0..compressed_data.len) |j| {
                    compressed_data[j] = try reader.interface.takeByte();
                }
            
                c.ddp_uncompress(uncompressed_data.ptr, l2_entry.uncompressed_size, compressed_data.ptr, l2_entry.compressed_size);
            }

            if(uncompressed_data[0] == 'D' and uncompressed_data[1] == 'D' and uncompressed_data[4] == 'H' and uncompressed_data[5] == 'X' and uncompressed_data[6] == 'B') {
                hxb_convert(uncompressed_data);
            }

            try out_dir.writeFile(io, .{ .sub_path = name, .data = uncompressed_data});
            _ = &reader.seekTo(pos); // Move back to next l2_entry
          
            getsize += l2_entry.size;
        }
    }

    std.debug.print("V: {x:0>8}", .{ header.magic });
    
}

// Seed is such a weird way to phrase it. It's really just the file length. The original repo this
// code was taken from just read this as three u8 values, but we can just read this as big endian.
// It's just a simple XOR encryption (at a u32 level), where file length is used the calculate a key
fn hxb_convert(data: []u8) void {
    const seed: i32 = (@as(i32,data[8]) << 16) | (@as(i32, data[9]) << 8) | @as(i32, data[10]);
    const key: i32 = (((seed << 5) ^ 0xA5) *% (seed +% 0x6F349)) ^ 0x34A9B129;
   
    std.debug.print("{} - {}\n", .{ seed, key });
    c.hxb_convert_seg(data.ptr, seed, key);
}

pub fn pack(file_paths: [][]const u8, destination: []const u8) !void {
    
    for(file_paths) |path| {
        std.debug.print("Input file: {}\n", .{ path });
    }

    std.debug.print("Destination: {}\n", .{ destination });
}
