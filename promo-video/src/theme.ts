import { loadFont } from "@remotion/fonts";
import { Easing, interpolate, staticFile, useVideoConfig } from "remotion";

// SF Pro comes from the system (the app itself uses the system font). The
// monospace face is bundled so renders do not depend on what is installed.
loadFont({
  family: "JetBrains Mono",
  url: staticFile("fonts/JetBrainsMono-Variable.woff2"),
  weight: "100 800",
});

export const FONT_SANS =
  'system-ui, -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif';
export const FONT_ROUNDED = '"SF Pro Rounded", system-ui, sans-serif';
export const FONT_MONO = '"JetBrains Mono", Menlo, monospace';

// macOS light-appearance values behind the app's DS* tokens
// (GenSnippets/DesignSystem.swift, AccentColor.colorset).
export const UI = {
  accent: "#007AFF",
  accentPressed: "#0062CC",
  windowBackground: "#ECECEC",
  controlBackground: "#FFFFFF",
  textBackground: "#FFFFFF",
  textPrimary: "rgba(0, 0, 0, 0.85)",
  textSecondary: "rgba(0, 0, 0, 0.5)",
  textTertiary: "rgba(0, 0, 0, 0.4)",
  placeholder: "rgba(0, 0, 0, 0.25)",
  surfaceSecondary: "rgba(0, 0, 0, 0.03)",
  selectedBackground: "rgba(0, 122, 255, 0.12)",
  border: "rgba(0, 0, 0, 0.09)",
  borderSubtle: "rgba(0, 0, 0, 0.06)",
  success: "#34C759",
};

/**
 * Scenes lay themselves out for the frame they are rendered into: 16:9 for X
 * and desktop, 9:16 for Reels. In 9:16 every caption and UI detail stays inside
 * the centre 1080×1350 band (y 285–1635), because Facebook's feed crops Reels
 * to roughly 4:5.
 */
export const useVertical = () => {
  const { width, height } = useVideoConfig();
  return height > width;
};

export const EASE_OUT = Easing.bezier(0.16, 1, 0.3, 1);
export const POP = Easing.spring({ damping: 14 });

export const ease = (
  frame: number,
  input: number[],
  output: number[],
  easing: (t: number) => number = EASE_OUT,
) =>
  interpolate(frame, input, output, {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing,
  });
