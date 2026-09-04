import Darwin
import Foundation

/// Reads per-core CPU tick counters from the Mach host.
///
/// `host_processor_info` hands back a kernel-allocated array of `integer_t`
/// laid out as `CPU_STATE_MAX` counters per logical core. The counters are
/// unsigned values delivered through a signed array, so every tick is decoded
/// with `UInt32(bitPattern:)`, and the buffer is always released with
/// `vm_deallocate`.
nonisolated struct MachCPUProvider: CPUMetricsProvider {

    /// Failure of the underlying Mach call, carrying its `kern_return_t`.
    nonisolated enum ReadError: Error, Equatable {
        case machCall(kern_return_t)
    }

    /// Cached host port. `mach_host_self()` returns a send right on every call,
    /// so it is acquired once instead of per sample.
    private let host: host_t

    init() {
        self.host = mach_host_self()
    }

    func readTicks() throws -> CPUTickSample {
        var coreCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let status = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &coreCount,
            &info,
            &infoCount
        )
        guard status == KERN_SUCCESS, let info else {
            throw ReadError.machCall(status)
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        let stateCount = Int(CPU_STATE_MAX)
        var cores: [CPUTicks] = []
        cores.reserveCapacity(Int(coreCount))

        for core in 0..<Int(coreCount) {
            let base = core * stateCount
            guard base + stateCount <= Int(infoCount) else { break }
            cores.append(
                CPUTicks(
                    user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                    system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                    idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                    nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
                )
            )
        }

        return CPUTickSample(cores: cores)
    }
}
