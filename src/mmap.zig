const Self = @This();
const uefi = @import("std").os.uefi;
const BootServices = uefi.tables.BootServices;

map: [*]uefi.tables.MemoryDescriptor = undefined,
size: usize = 0,
key: usize = undefined,
descSize: usize = undefined,
descVer: u32 = undefined,

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
    while (.BufferTooSmall != bs.getMemoryMap(
        &self.size,
        self.map,
        &self.key,
        &self.descSize,
        &self.descVer,
    )) {
        if (.Success != bs.freePool(@ptrCast(&self.size))) {
            return error.UnableToFreePool;
        }
        if (.Success != bs.allocatePool(
            .BootServicesData,
            self.size,
            @ptrCast(&self.map),
        )) {
            return error.UnableToAllocatePool;
        }
    }
}
