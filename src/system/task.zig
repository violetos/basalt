// Copyright (c) 2024-2026 YiraSan
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// --- dependencies --- //

const std = @import("std");
const builtin = @import("builtin");

// --- system/task.zig --- //

pub const Priority = enum(u2) {
    /// Base quantum: 20ms
    background = 0b00,
    /// Base quantum: 4ms
    normal = 0b01,
    /// Base quantum: 2ms
    ///
    /// Unprivileged can only create one.
    reactive = 0b10,
    /// Base quantum: 2ms
    ///
    /// Reserved to privileged.
    realtime = 0b11,
};

pub const QuantumDivisor = enum(u2) {
    full = 0b00,
    quarter = 0b01,
    half = 0b10,
    double = 0b11,
};

const ns_per_uis = 1024;
const ns_per_mis = 1024 * ns_per_uis;

pub const Settings = packed struct(u64) {
    /// Represents the CPU index to which the task has strong affinity bias.
    ///
    /// affinity == 255 means NO_AFF.
    ///
    /// The affinity bias means that for any mean, the task will stay longer on its affinity CPU,
    /// and shorter if the the task is not on it.
    ///
    /// The affinity CPU index is `(affinity_offset + affinity) % cpu_count`.
    ///
    /// The affinity_offset is randomly given to the process at creation.
    ///
    /// If the system have 8 CPUs, and the task affinity is 21.
    /// It means that the task will have affinity to the CPU 5 (21 % 8).
    ///
    /// This allows for the program to indicate how the kernel should balance task load for that specific program.
    ///
    /// The recommended strategy is to set NO_AFF for non-worker task.
    /// And for every worker in a same pool, having sequential affinity.
    ///
    /// Real-time task are guaranteed to be binded to their affinity CPU.
    affinity: u8 = 255,
    priority: Priority,
    qt_div: QuantumDivisor,
    _padding: u52 = 0,

    pub fn getGranularity(self: Settings) u64 {
        return switch (self.priority) {
            .realtime => 16 * ns_per_uis,
            .reactive => 32 * ns_per_uis,
            .normal, .background => 1 * ns_per_mis,
        };
    }

    pub fn getQuantum(self: Settings) u64 {
        return switch (self.priority) {
            .background => switch (self.qt_div) {
                .full => 16 * ns_per_mis,
                .quarter => 4 * ns_per_mis,
                .half => 8 * ns_per_mis,
                .double => 32 * ns_per_mis,
            },
            .normal => switch (self.qt_div) {
                .full => 4 * ns_per_mis,
                .quarter => 1 * ns_per_mis,
                .half => 2 * ns_per_mis,
                .double => 8 * ns_per_mis,
            },
            .reactive, .realtime => switch (self.qt_div) {
                .full => 2 * ns_per_mis,
                .quarter => 512 * ns_per_uis,
                .half => 1 * ns_per_mis,
                .double => 4 * ns_per_mis,
            },
        };
    }

    pub fn getDelay(self: Settings) u64 {
        if (self.priority == .realtime) return 0;

        const base_delay: u64 = switch (self.priority) {
            .realtime => unreachable,
            .reactive => 0,
            .normal => 2 * ns_per_mis,
            .background => 16 * ns_per_mis,
        };

        return base_delay + self.getQuantum();
    }
};
