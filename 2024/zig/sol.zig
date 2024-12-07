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

fn d3_part_two_(input: []const u8) u32 {
    var total: u32 = 0;

    var current: usize = 0;
    const input_len = input.len;
    var enabled = true;
    while (current < input_len) {
        if (current + 4 < input.len and std.mem.eql(u8, input[current .. current + 4], "mul(")) {
            current += 4;
            if (!enabled) {
                continue;
            }
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
        } else if (current + 7 < input.len and std.mem.eql(u8, input[current .. current + 7], "don't()")) {
            current += 7;
            enabled = false;
            continue;
        } else if (current + 4 < input.len and std.mem.eql(u8, input[current .. current + 4], "do()")) {
            current += 4;
            enabled = true;
            continue;
        }

        current += 1;
    }

    return total;
}

test "day three: part two" {
    try expect(d3_part_two_("xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))") == 48);
}

fn d3_part_two() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = try std.fs.cwd().readFileAlloc(allocator, "inputs/03.txt", 1000000);
    defer allocator.free(content);
    std.debug.print("{}", .{d3_part_two_(content)});
}

const Direction = enum(u3) { E, NE, N, NW, W, SW, S, SE };

var DIRECTIONS = std.EnumArray(Direction, struct { dx: i2, dy: i2 }).init(.{
    .E = .{ .dx = 1, .dy = 0 }, // Right (unchanged)
    .NE = .{ .dx = 1, .dy = -1 }, // Right and up
    .N = .{ .dx = 0, .dy = -1 }, // Up
    .NW = .{ .dx = -1, .dy = -1 }, // Left and up
    .W = .{ .dx = -1, .dy = 0 }, // Left (unchanged)
    .SW = .{ .dx = -1, .dy = 1 }, // Left and down
    .S = .{ .dx = 0, .dy = 1 }, // Down
    .SE = .{ .dx = 1, .dy = 1 }, // Right and down
});

const Point = struct {
    x: usize,
    y: usize,

    pub fn hash(self: Point) u64 {
        var hasher = std.hash.Wyhash.init(0);
        const xb = std.mem.asBytes(&self.x);
        const yb = std.mem.asBytes(&self.y);
        hasher.update(xb);
        hasher.update(yb);
        return hasher.final();
    }

    pub fn eql(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }
};

const DirectedPoint = struct { point: Point, dir: Direction };
const AdjPoints = struct { points: [8]DirectedPoint, len: usize };

fn move_one(p: Point, dir_e: Direction, max_x: usize, max_y: usize) ?Point {
    const dir = DIRECTIONS.get(dir_e);
    if (dir.dx == 0 and dir.dy == 0) {
        return p;
    }
    const new_x: usize = if (dir.dx < 0)
        if (p.x == 0) {
            return null;
        } else p.x - @as(usize, @intCast(-dir.dx))
    else
        p.x + @as(usize, @intCast(dir.dx));

    const new_y: usize = if (dir.dy < 0)
        if (p.y == 0) {
            return null;
        } else p.y - @as(usize, @intCast(-dir.dy))
    else
        p.y + @as(usize, @intCast(dir.dy));

    if (new_x > max_x or new_y > max_y) {
        return null;
    }

    return Point{ .x = new_x, .y = new_y };
}

fn adj_ind(i: usize, j: usize, max_x: usize, max_y: usize) AdjPoints {
    var points: [8]DirectedPoint = undefined;
    var ind: usize = 0;
    var iter = DIRECTIONS.iterator();
    while (iter.next()) |entry| {
        const new_point = move_one(Point{ .x = i, .y = j }, entry.key, max_x, max_y) orelse continue;

        points[ind] = DirectedPoint{ .point = new_point, .dir = entry.key };
        ind += 1;
    }

    return AdjPoints{ .points = points, .len = ind };
}

fn d4_part_one_(input: []const u8) !u32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var xp = std.AutoHashMap(Point, void).init(allocator);
    defer xp.deinit();

    var mp = std.AutoHashMap(Point, void).init(allocator);
    defer mp.deinit();

    var ap = std.AutoHashMap(Point, void).init(allocator);
    defer ap.deinit();

    var sp = std.AutoHashMap(Point, void).init(allocator);
    defer sp.deinit();

    var lines = std.mem.split(u8, input, "\n");

    var row: usize = 0;
    var cols: usize = 0;
    while (lines.next()) |line| {
        if (cols == 0) {
            cols = line.len;
        }

        for (line, 0..) |char, col| {
            switch (char) {
                'X' => try xp.put(Point{ .x = row, .y = col }, {}),
                'M' => try mp.put(Point{ .x = row, .y = col }, {}),
                'A' => try ap.put(Point{ .x = row, .y = col }, {}),
                'S' => try sp.put(Point{ .x = row, .y = col }, {}),
                else => {},
            }
        }

        row += 1;
    }

    var xiter = xp.keyIterator();
    var total: u32 = 0;
    while (xiter.next()) |p| {
        const adp = adj_ind(p.*.x, p.*.y, row, cols);
        for (0..adp.len) |i| {
            const dir_point = adp.points[i];

            const potential_m = dir_point.point;
            const potential_a = move_one(potential_m, dir_point.dir, cols, row) orelse continue;
            const potential_s = move_one(potential_a, dir_point.dir, cols, row) orelse continue;
            if (mp.contains(potential_m) and ap.contains(potential_a) and sp.contains(potential_s)) {
                // std.debug.print("found at ({}, {})\n", .{ p.x, p.y });
                total += 1;
            }
        }
    }

    return total;
}

test "day 04: part one" {
    const input =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;

    try expect(try d4_part_one_(input) == 18);
}

fn d4_part_one() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = try std.fs.cwd().readFileAlloc(allocator, "inputs/04.txt", 1000000);
    defer allocator.free(content);
    std.debug.print("{!}", .{d4_part_one_(content)});
}

fn getAdjDirectionPointMap(adj_points: AdjPoints) std.EnumMap(Direction, Point) {
    var map = std.EnumMap(Direction, Point){};
    var i: usize = 0;
    while (i < adj_points.len) : (i += 1) {
        const directed_point = adj_points.points[i];
        map.put(directed_point.dir, directed_point.point);
    }

    return map;
}

fn d4_part_two_(input: []const u8) !u32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var xp = std.AutoHashMap(Point, void).init(allocator);
    defer xp.deinit();

    var mp = std.AutoHashMap(Point, void).init(allocator);
    defer mp.deinit();

    var ap = std.AutoHashMap(Point, void).init(allocator);
    defer ap.deinit();

    var sp = std.AutoHashMap(Point, void).init(allocator);
    defer sp.deinit();

    var lines = std.mem.split(u8, input, "\n");

    var row: usize = 0;
    var cols: usize = 0;
    while (lines.next()) |line| {
        if (cols == 0) {
            cols = line.len;
        }

        for (line, 0..) |char, col| {
            switch (char) {
                'X' => try xp.put(Point{ .y = row, .x = col }, {}),
                'M' => try mp.put(Point{ .y = row, .x = col }, {}),
                'A' => try ap.put(Point{ .y = row, .x = col }, {}),
                'S' => try sp.put(Point{ .y = row, .x = col }, {}),
                else => {},
            }
        }

        row += 1;
    }

    var aiter = ap.keyIterator();
    var total: u32 = 0;
    while (aiter.next()) |p| {
        const adp = adj_ind(p.*.x, p.*.y, row, cols);
        const pmap = getAdjDirectionPointMap(adp);

        const up_right_1 = sp.contains(pmap.get(Direction.NE) orelse continue) and mp.contains(pmap.get(Direction.SW) orelse continue);
        const up_right_2 = mp.contains(pmap.get(Direction.NE) orelse continue) and sp.contains(pmap.get(Direction.SW) orelse continue);
        const up_left_1 = mp.contains(pmap.get(Direction.NW) orelse continue) and sp.contains(pmap.get(Direction.SE) orelse continue);
        const up_left_2 = sp.contains(pmap.get(Direction.NW) orelse continue) and mp.contains(pmap.get(Direction.SE) orelse continue);

        if ((up_right_1 or up_right_2) and (up_left_1 or up_left_2)) {
            total += 1;
        }
    }

    return total;
}
fn d4_part_two() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = try std.fs.cwd().readFileAlloc(allocator, "inputs/04.txt", 1000000);
    defer allocator.free(content);
    std.debug.print("{!}", .{d4_part_two_(content)});
}
test "day 04: part two" {
    const input =
        \\.M.S......
        \\..A..MSMS.
        \\.M.S.MAA..
        \\..A.ASMSM.
        \\.M.S.M....
        \\..........
        \\S.S.S.S.S.
        \\.A.A.A.A..
        \\M.M.M.M.M.
        \\..........
    ;

    try expect(try d4_part_two_(input) == 9);
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
    std.debug.print("\n", .{});
    try d3_part_two();

    std.debug.print("\n\nDay 04: \n", .{});
    try d4_part_one();
    std.debug.print("\n", .{});
    try d4_part_two();
}
