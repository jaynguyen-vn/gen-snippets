/**
 * Note: When using the Node.JS APIs, the config file
 * doesn't apply. Instead, pass options directly to the APIs.
 *
 * All configuration options: https://remotion.dev/docs/config
 */

import { Config } from "@remotion/cli/config";

Config.setRspack(true);
Config.setVideoImageFormat("jpeg");
// Default 80 bands the dark gradients and softens small UI text.
Config.setJpegQuality(95);
// The default color space encodes full-range yuvj420p; bt709 gives tagged,
// limited-range yuv420p that plays back the same everywhere (QuickTime, X, YouTube).
Config.setPixelFormat("yuv420p");
Config.setColorSpace("bt709");
Config.setOverwriteOutput(true);
