import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";

/** Dark backdrop with two slowly drifting glows; shared by every scene. */
export const Background: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const t = frame / durationInFrames;

  return (
    <AbsoluteFill style={{ backgroundColor: "#05060B" }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at ${interpolate(t, [0, 1], [16, 34])}% ${interpolate(t, [0, 1], [18, 30])}%, rgba(0, 122, 255, 0.36) 0%, rgba(0, 122, 255, 0) 46%)`,
        }}
      />
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at ${interpolate(t, [0, 1], [88, 70])}% ${interpolate(t, [0, 1], [86, 72])}%, rgba(94, 92, 230, 0.3) 0%, rgba(94, 92, 230, 0) 44%)`,
        }}
      />
      <AbsoluteFill style={{ boxShadow: "inset 0 0 320px rgba(0, 0, 0, 0.65)" }} />
    </AbsoluteFill>
  );
};
