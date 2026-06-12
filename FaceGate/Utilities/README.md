# Utilities

Helper structures and low-level wrappers that support the broader application logic.

## Contents

- **`KeychainHelper`**: A clean, Swift-friendly wrapper around the legacy C-based `Security` framework for secure credential storage.
- **`CryptoHelper`**: Utilizes `CryptoKit` (AES-256-GCM) to encrypt and decrypt the user's face embedding vectors at rest.
- **`InstalledAppsScanner`**: Parses `/Applications` to populate the user-facing list of apps available to lock.
- **`VectorMath`**: Hardware-accelerated math using the `Accelerate` framework (`vDSP`) for high-performance cosine similarity and L2 distance calculations during face matching.
- **`Constants`**: Centralized definition of UserDefaults keys and app-wide identifiers.
