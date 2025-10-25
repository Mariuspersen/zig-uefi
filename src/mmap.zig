const Self = @This();
const uefi = @import("std").os.uefi;
const BootServices = uefi.tables.BootServices;
const MemoryDescriptor = uefi.tables.MemoryDescriptor;

map: [*]MemoryDescriptor = undefined,
size: usize = 0,
key: usize = 0,
descSize: usize = 0,
descVer: u32 = 0,

pub fn init(bs: *BootServices) !Self {
    var self: Self = .{};
    try updateMap(&self, bs);
    return self;
}

pub fn exitBootService(self: *Self, bs: *BootServices) !void {
    if (.Success != bs.exitBootServices(uefi.handle, self.key)) {
        return error.UnableToExitBootServices;
    }
}

pub fn attemptToExitBootService(self: *Self, bs: *BootServices) !void {
    while (true) {
        try self.updateMap(bs);
        self.exitBootService(bs) catch continue;
        break;
    }
}

pub fn updateMap(self: *Self, bs: *BootServices) !void {
    while (.buffer_too_small == bs.getMemoryMap(
        &self.size,
        self.map,
        &self.key,
        &self.descSize,
        &self.descVer,
    )) {
        if (.success != bs.allocatePool(
            .boot_services_data,
            self.size,
            @ptrCast(&self.*.map),
        )) {
            return error.UnableToAllocatePool;
        }   
    }
}

pub fn getSlice(self: *const Self) []MemoryDescriptor {
    return self.map[0..self.size / self.descSize];
}
