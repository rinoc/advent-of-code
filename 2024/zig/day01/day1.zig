const std = @import("std");

fn insertion_sort(arr: []u32) void {
    for (1..arr.len) |i| {
        // loop invariant: arr[0..i] is sorted
        const key = arr[i];
        var j: i32 = @intCast(i - 1);
        while (j >= 0 and arr[@intCast(j)] > key) {
            // arr[0..j] is sorted, arr[j..i]
            arr[@intCast(j + 1)] = arr[@intCast(j)];
            j -= 1;
        }

        // arr[j] <= key
        arr[@intCast(j + 1)] = key;
    }
}

const InputLists = struct {
    list1: [1000]u32,
    list2: [1000]u32,
};

fn read_input() !InputLists {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    var list1 = [_]u32{0} ** 1000;
    var list2 = [_]u32{0} ** 1000;
    var i: usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const num1 = try std.fmt.parseUnsigned(u32, line[0..5], 10);
        const num2 = try std.fmt.parseUnsigned(u32, line[8..13], 10);
        list1[i] = num1;
        list2[i] = num2;
        i += 1;
    }

    return InputLists{ .list1 = list1, .list2 = list2 };
}

fn hashUint(val: u32) u32 {
    var result = val;
    // FNV-1a inspired hash
    result ^= result >> 16;
    result *%= 0x85ebca6b; // Use wrapping multiplication
    result ^= result >> 13;
    result *%= 0xc2b2ae35; // Use wrapping multiplication
    result ^= result >> 16;
    return result;
}

pub const HashTable = struct {
    const Self = @This();

    const Node = struct { key: u32, value: u32, next: ?*Node };
    const Bucket = struct { head: ?*Node };

    arena: std.heap.ArenaAllocator,
    buckets: []Bucket,
    size: usize,

    pub fn init(allocator: std.mem.Allocator, initial_size: usize) !Self {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const buckets = try arena.allocator().alloc(Bucket, initial_size);

        for (buckets) |*bucket| {
            bucket.* = .{ .head = null };
        }

        return .{ .arena = arena, .buckets = buckets, .size = initial_size };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    pub fn put(self: *Self, key: u32, value: u32) !void {
        const hash = hashUint(key);
        const key_index = hash % self.size;

        var maybe_node = self.buckets[key_index].head;

        while (maybe_node) |node| {
            if (node.key == key) {
                node.value = value;
                return;
            }
            maybe_node = node.next;
        }

        const new_node = try self.arena.allocator().create(Node);
        new_node.* = .{ .key = key, .value = value, .next = self.buckets[key_index].head };

        self.buckets[key_index].head = new_node;
    }

    pub fn get(self: Self, key: u32) ?u32 {
        const hash = hashUint(key);
        const key_index = hash % self.size;

        var maybe_node = self.buckets[key_index].head;

        while (maybe_node) |node| {
            if (node.key == key) {
                return node.value;
            }
            maybe_node = node.next;
        }

        return null;
    }
};

fn part_one() !void {
    const input = read_input() catch |err| {
        std.debug.print("Failed to read input: {any}\n", .{err});
        std.process.exit(1);
    };
    var list1 = input.list1;
    var list2 = input.list2;
    insertion_sort(list1[0..]);
    insertion_sort(list2[0..]);

    var total: u32 = 0;

    for (0..1000) |j| {
        total += if (list1[j] > list2[j]) (list1[j] - list2[j]) else (list2[j] - list1[j]);
    }

    std.debug.print("{}", .{total});
}

fn part_two() !void {
    const input = read_input() catch |err| {
        std.debug.print("Failed to read input: {any}\n", .{err});
        std.process.exit(1);
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var ht = try HashTable.init(allocator, 10);

    for (input.list2) |num| {
        const cur = ht.get(num);
        try ht.put(num, if (cur) |val| val + 1 else 1);
    }

    var total: u32 = 0;
    for (input.list1) |num| {
        // std.debug.print("[{}]: {} ---\n", .{ i, num });

        if (ht.get(num)) |val| {
            // std.debug.print("{} {}\n", .{ val, num });
            total += val * num;
        }
    }

    std.debug.print("{}", .{total});
}

pub fn main() !void {
    try part_one();
    std.debug.print("\n\n", .{});
    try part_two();
}
