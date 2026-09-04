import Testing

extension Tag {
    /// Tests that touch real hardware interfaces (Mach, sysctl, IORegistry).
    @Tag static var integration: Self
}
