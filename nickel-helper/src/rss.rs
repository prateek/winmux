//! The helper's resident memory, which WinMux reads from every reply to decide when to replace it.

/// Resident set size in bytes, or 0 if the kernel does not report it.
pub fn resident_bytes() -> u64 {
    let mut info = std::mem::MaybeUninit::<libc::proc_taskinfo>::zeroed();
    let size = std::mem::size_of::<libc::proc_taskinfo>() as libc::c_int;
    // SAFETY: `info` is a writable buffer of `size` bytes, which is what PROC_PIDTASKINFO fills.
    let written = unsafe {
        libc::proc_pidinfo(libc::getpid(), libc::PROC_PIDTASKINFO, 0, info.as_mut_ptr().cast(), size)
    };
    if written != size {
        return 0;
    }
    // SAFETY: the kernel filled the whole struct.
    unsafe { info.assume_init() }.pti_resident_size
}
