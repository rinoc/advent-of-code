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

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    var list1: [1000]u32 = undefined;
    var list2: [1000]u32 = undefined;
    var i: usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const num1 = try std.fmt.parseUnsigned(u32, line[0..5], 10);
        const num2 = try std.fmt.parseUnsigned(u32, line[8..13], 10);
        list1[i] = num1;
        list2[i] = num2;
        i += 1;
    }

    insertion_sort(&list1);
    insertion_sort(&list2);

    var total: u32 = 0;

    for (0..1000) |j| {
        total += if (list1[j] > list2[j]) (list1[j] - list2[j]) else (list2[j] - list1[j]);
    }

    std.debug.print("{}", .{total});
}
