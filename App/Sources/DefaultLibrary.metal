#include <metal_stdlib>
using namespace metal;

// This file exists solely so the build produces a `default.metallib` inside the app bundle.
//
// SpriteKit loads the default Metal library when it first renders. If the app bundle has no
// `default.metallib` (which happens when the project contains zero .metal files), SpriteKit
// ends up calling -[MTLDevice newLibraryWithURL:nil], which fails the assertion
// "url must not be nil" and crashes at the first frame. Shipping one trivial shader forces
// the build to emit default.metallib, which resolves the crash.
kernel void macbadcat_keep_default_metallib() {}
