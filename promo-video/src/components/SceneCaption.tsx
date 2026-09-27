import React from "react";
import { Easing, Interactive, interpolate } from "remotion";
import { useVertical } from "../theme";

/**
 * Headline plus optional sub line at the top of a scene. Both wrap in 9:16,
 * so they sit in one flex column instead of at fixed offsets.
 */
export const SceneCaption: React.FC<{
  frame: number;
  title: React.ReactNode;
  sub?: React.ReactNode;
  enterAt?: number;
  exitAt?: number;
}> = ({ frame, title, sub, enterAt = 2, exitAt }) => {
  const vertical = useVertical();
  const exit = exitAt ?? Infinity;
  const fadeOut = exitAt === undefined ? 1 : interpolate(frame, [exit, exit + 6], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const lift = exitAt === undefined ? 0 : interpolate(frame, [exit, exit + 8], [0, -24], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <div
      style={{
        position: "absolute",
        top: vertical ? 300 : 84,
        left: vertical ? 60 : 0,
        right: vertical ? 60 : 0,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: vertical ? 22 : 12,
        textAlign: "center",
        opacity: fadeOut,
        translate: `0px ${lift}px`,
      }}
    >
      <Interactive.Div
        name="Caption"
        style={{
          fontSize: vertical ? 84 : 80,
          fontWeight: 700,
          letterSpacing: "-0.03em",
          lineHeight: 1.08,
          textWrap: "balance",
          color: "white",
          opacity: interpolate(frame, [enterAt, enterAt + 12], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
          translate: interpolate(frame, [enterAt, enterAt + 18], ["0px 30px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        {title}
      </Interactive.Div>
      {sub ? (
        <Interactive.Div
          name="Subcaption"
          style={{
            fontSize: vertical ? 44 : 42,
            fontWeight: 500,
            lineHeight: 1.3,
            textWrap: "balance",
            color: "rgba(255, 255, 255, 0.72)",
            opacity: interpolate(frame, [enterAt + 6, enterAt + 18], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
            translate: interpolate(frame, [enterAt + 6, enterAt + 24], ["0px 24px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          {sub}
        </Interactive.Div>
      ) : null}
    </div>
  );
};
