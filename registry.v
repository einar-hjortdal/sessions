module sessions

// A registry caches session data.
// Invoking the `Store.new` method often involves decoding and verifying signatures, invoking this method
// multiple times is unnecessary. The `Store.get` method will cache the loaded data and make it available
// until the `Store.save` method is utilized.
