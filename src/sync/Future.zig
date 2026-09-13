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

// --- imports --- //

const basalt = @import("basalt");

// --- sync/Future.zig --- //

const Future = @This();

handle: u64,

// --- //

pub const State = enum(u8) {
    pending = 0,
    resolved = 1,
    canceled = 2,
};

pub const Kind = enum(u8) {
    /// The future is destroyed after consumation.
    single = 0,
    /// The future is reset to .pending after consumation.
    /// A producer can't resolve/cancel again until consumation.
    multi = 0,
    /// The task has a state relative to the .wait compare_value.
    relative = 1,
};
