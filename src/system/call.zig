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

// --- imports --- //

const basalt = @import("basalt");

// --- system/call.zig --- //

pub const Code = enum(u64) {
    null = 0x00,

    mem_map = 0x10,
    mem_unmap = 0x11,
    mem_edit = 0x12,
    mem_share = 0x13,

    handler_set = 0x20,
    handler_exit = 0x21,

    process_terminate = 0x30,

    task_terminate = 0x40,
    task_yield = 0x41,

    future_create = 0x51,
    future_bind = 0x52,
    future_cmd = 0x53,
    future_gate = 0x54,

    vector_create = 0x60,
    vector_destroy = 0x61,
    vector_bind = 0x62,
    vector_line = 0x63,
    vector_consume = 0x64,

    line_drop = 0x71,
    line_invoke = 0x72,

    timer_single = 0x80,
    timer_sequential = 0x81,
};

// Keep in sync with the biggest syscall code.
pub const MAX_CODE = @backingInt(Code.timer_sequential) + 1;

pub const Error = error{
    UnknownCode,
    InternalFailure,
};

pub const ErrorCode = enum(u16) {
    unknown_code = 0,
    internal_failure = 1,

    pub fn toError(self: @This()) Error {
        return switch (self) {
            .unknown_code => Error.UnknownCode,
            .internal_failure => Error.InternalFailure,
        };
    }
};

pub const ResultArgs = packed struct(u64) {
    is_success: bool, // bit 0
    _reserved: u15 = 0, // bits 1-15
    value: packed union {
        err: packed struct(u48) {
            error_code: ErrorCode = .unknown_code, // bits 16-31
            _reserved: u32 = 0, // bits 32-63
        },
        success: packed struct(u48) {
            val0: u16 = 0, // bits 16-31
            val1: u32 = 0, // bits 32-63
        },
    },
};

pub const FullResult = extern struct {
    args: ResultArgs,
    val2: u64,
};

pub const ResultVals = struct {
    val0: u16 = 0,
    val1: u32 = 0,
    val2: u64 = 0,
};

// --- //

pub const KernelIndirectionTable = extern struct {
    major_version: u32,
    minor_version: u32,

    call_system: *const fn (
        code: Code,
        arg1: u64,
        arg2: u64,
        arg3: u64,
        arg4: u64,
        arg5: u64,
        arg6: u64,
        arg7: u64,
    ) callconv(basalt.system.call_conv) FullResult,
};

pub var kit: *const KernelIndirectionTable = if (basalt.system.is_module) undefined else unreachable;

// --- //

inline fn userland_fn(
    code: Code,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
    arg5: u64,
    arg6: u64,
    arg7: u64,
) FullResult {
    var code_val: u64 = @backingInt(code);
    var arg1_val: u64 = arg1;

    switch (builtin.target.cpu.arch) {
        .aarch64 => {
            asm volatile (
                \\svc #0
                : [code] "+{x0}" (code_val),
                  [arg1] "+{x1}" (arg1_val),
                : [arg2] "{x2}" (arg2),
                  [arg3] "{x3}" (arg3),
                  [arg4] "{x4}" (arg4),
                  [arg5] "{x5}" (arg5),
                  [arg6] "{x6}" (arg6),
                  [arg7] "{x7}" (arg7),
                : .{
                  .memory = true,
                  .nzcv = true,
                });

            return .{
                .args = @bitCast(code_val),
                .val2 = arg1_val,
            };
        },
        .riscv64 => {
            asm volatile (
                \\ecall
                : [code] "+{a0}" (code_val),
                  [arg1] "+{a1}" (arg1_val),
                : [arg2] "{a2}" (arg2),
                  [arg3] "{a3}" (arg3),
                  [arg4] "{a4}" (arg4),
                  [arg5] "{a5}" (arg5),
                  [arg6] "{a6}" (arg6),
                  [arg7] "{a7}" (arg7),
                : .{
                  .memory = true,
                });

            return .{
                .args = @bitCast(code_val),
                .val2 = arg1_val,
            };
        },
        else => unreachable,
    }
}

pub const SyscallArgs = struct {
    arg1: u64 = 0,
    arg2: u64 = 0,
    arg3: u64 = 0,
    arg4: u64 = 0,
    arg5: u64 = 0,
    arg6: u64 = 0,
    arg7: u64 = 0,
};

pub fn syscall(code: Code, args: SyscallArgs) Error!ResultVals {
    const full_result: FullResult = if (basalt.system.is_module)
        @call(.auto, kit.call_system, .{code} ++ .{ args.arg1, args.arg2, args.arg3, args.arg4, args.arg5, args.arg6, args.arg7 })
    else
        @call(.auto, userland_fn, .{code} ++ .{ args.arg1, args.arg2, args.arg3, args.arg4, args.arg5, args.arg6, args.arg7 });

    if (!full_result.args.is_success) {
        return full_result.args.value.err.error_code.toError();
    }

    return .{
        .val0 = full_result.args.value.success.val0,
        .val1 = full_result.args.value.success.val1,
        .val2 = full_result.val2,
    };
}

// --- //

pub const WaitMode = enum(u8) {
    /// For a real-time task, use .no_suspend; otherwise, use .wait.
    /// Useful for an agnostic library.
    auto = 0x00,
    no_suspend = 0x01,
    wait = 0x02,
};
