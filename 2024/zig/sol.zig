const std = @import("std");
const expect = std.testing.expect;

/// Helpers
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

/// Day One
const InputLists = struct {
    list1: [1000]u32,
    list2: [1000]u32,
};

fn read_input() !InputLists {
    const file = try std.fs.cwd().openFile("inputs/01.txt", .{});
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

fn d1_part_one() !void {
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

fn d1_part_two() !void {
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

/// Day Two
fn absInt(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    if (@typeInfo(T) != .Int) @compileError("abs requires integer type");

    return if (x >= 0) x else -x;
}

fn d2_is_safe(nums: []const i16) bool {
    var window_iterator = std.mem.window(i16, nums, 2, 1);

    // increasing
    var increasing = true;
    while (window_iterator.next()) |pair| {
        if (pair[1] <= pair[0]) {
            increasing = false;
            break;
        }
    }

    window_iterator = std.mem.window(i16, nums, 2, 1);

    var decreasing = true;
    while (window_iterator.next()) |pair| {
        if (pair[0] <= pair[1]) {
            decreasing = false;
            break;
        }
    }

    window_iterator = std.mem.window(i16, nums, 2, 1);

    var diff_check = true;
    while (window_iterator.next()) |pair| {
        const diff = absInt(pair[0] - pair[1]);
        if (diff == 0 or diff > 3) {
            diff_check = false;
            break;
        }
    }

    return (increasing or decreasing) and diff_check;
}

test "d2_is_safe specified test cases" {
    // "7 6 4 2 1": Safe because the levels are all decreasing by 1 or 2
    try expect(d2_is_safe(&[_]i16{ 7, 6, 4, 2, 1 }));

    // "1 2 7 8 9": Unsafe because 2 7 is an increase of 5
    try expect(!d2_is_safe(&[_]i16{ 1, 2, 7, 8, 9 }));

    // "9 7 6 2 1": Unsafe because 6 2 is a decrease of 4
    try expect(!d2_is_safe(&[_]i16{ 9, 7, 6, 2, 1 }));

    // "1 3 2 4 5": Unsafe because 1 3 is increasing but 3 2 is decreasing
    try expect(!d2_is_safe(&[_]i16{ 1, 3, 2, 4, 5 }));

    // "8 6 4 4 1": Unsafe because 4 4 is neither an increase or decrease
    try expect(!d2_is_safe(&[_]i16{ 8, 6, 4, 4, 1 }));

    // "1 3 6 7 9": Safe because the levels are all increasing by 1, 2, or 3
    try expect(d2_is_safe(&[_]i16{ 1, 3, 6, 7, 9 }));
}

fn d2_line_to_nums(allocator: std.mem.Allocator, line: []const u8) ![]i16 {
    var iterator = std.mem.split(u8, line, " ");
    var numbers = std.ArrayList(i16).init(allocator);
    defer numbers.deinit();

    while (iterator.next()) |token| {
        const num = try std.fmt.parseInt(i16, token, 10);
        try numbers.append(num);
    }

    return numbers.toOwnedSlice();
}

fn d2_part_one() !void {
    const file = try std.fs.cwd().openFile("inputs/02.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var buf: [1024]u8 = undefined;

    var num_safe: u32 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const nums = try d2_line_to_nums(allocator, line);
        const is_safe = d2_is_safe(nums);
        if (is_safe) {
            num_safe += 1;
        }
    }

    std.debug.print("{}", .{num_safe});
}

fn d2_part_two() !void {
    const file = try std.fs.cwd().openFile("inputs/02.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var buf: [1024]u8 = undefined;

    var num_safe: u32 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const nums = try d2_line_to_nums(allocator, line);
        for (0..nums.len) |i| {
            var new_slice = try allocator.alloc(i16, nums.len - 1);
            @memcpy(new_slice[0..i], nums[0..i]);
            @memcpy(new_slice[i..], nums[i + 1 ..]);
            const is_safe = d2_is_safe(new_slice);
            if (is_safe) {
                num_safe += 1;
                break;
            }
        }
    }

    std.debug.print("{}", .{num_safe});
}

/// Day Three
///
fn is_digit(c: u8) bool {
    return c >= '0' and c <= '9';
}
fn d3_part_one_(input: []const u8) u32 {
    var total: u32 = 0;

    var current: usize = 0;
    const input_len = input.len;
    while (current < input_len) {
        if (current + 4 < input.len and std.mem.eql(u8, input[current .. current + 4], "mul(")) {
            current += 4;
            var one: u32 = 0;
            while (is_digit(input[current])) {
                one = 10 * one + (input[current] - '0');
                current += 1;
            }
            if (input[current] != ',') {
                continue;
            }
            current += 1;
            var two: u32 = 0;
            while (is_digit(input[current])) {
                two = 10 * two + (input[current] - '0');
                current += 1;
            }
            if (input[current] != ')') {
                continue;
            }

            total += one * two;
            continue;
        }

        current += 1;
    }

    return total;
}

test "day three: find mul sums" {
    try expect(d3_part_one_("xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))") == 161);
}

fn d3_part_one() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = try std.fs.cwd().readFileAlloc(allocator, "inputs/03.txt", 1000000);
    defer allocator.free(content);
    std.debug.print("{}", .{d3_part_one_(content)});
}

pub fn main() !void {
    std.debug.print("Day 01: \n", .{});
    try d1_part_one();
    std.debug.print("\n", .{});
    try d1_part_two();

    std.debug.print("\n\nDay 02: \n", .{});
    try d2_part_one();
    std.debug.print("\n", .{});
    try d2_part_two();

    std.debug.print("\n\nDay 03: \n", .{});
    try d3_part_one();
}
