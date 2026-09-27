import React from "react";
import { AbsoluteFill, Easing, Interactive, interpolate, useCurrentFrame } from "remotion";
import { ExitWhoosh, Sfx } from "../audio";
import { FONT_SANS, useVertical } from "../theme";

const PHRASES = [
  "Best regards, Alex Morgan",
  "Thanks for reaching out!",
  "123 Main Street, Apt 4B",
  "Let me know if you have any questions.",
  "alex@example.com",
  "Looking forward to hearing from you.",
];

/** Rows of the phrases people retype all day, drifting behind the headline. */
const GhostRows: React.FC<{ frame: number }> = ({ frame }) => (
  <AbsoluteFill
    style={{
      justifyContent: "space-evenly",
      opacity: interpolate(frame, [0, 20], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
      maskImage: "radial-gradient(ellipse 46% 34% at 50% 50%, transparent 30%, black 100%)",
      WebkitMaskImage: "radial-gradient(ellipse 46% 34% at 50% 50%, transparent 30%, black 100%)",
    }}
  >
    {PHRASES.map((phrase, row) => (
      <div
        key={phrase}
        style={{
          whiteSpace: "nowrap",
          fontFamily: FONT_SANS,
          fontSize: 46,
          fontWeight: 500,
          color: "rgba(255, 255, 255, 0.07)",
          translate: `${(row % 2 === 0 ? -1 : 1) * frame * 1.6 - 400 - row * 140}px 0px`,
        }}
      >
        {Array.from({ length: 6 }, () => phrase).join("   ·   ")}
      </div>
    ))}
  </AbsoluteFill>
);

export const HookScene: React.FC = () => {
  const frame = useCurrentFrame();
  const vertical = useVertical();

  return (
    <AbsoluteFill style={{ fontFamily: FONT_SANS }}>
      {/* One pop per word. */}
      <Sfx at={31} name="pop-word" volume={0.6} />
      <Sfx at={47} name="pop-word" volume={0.6} />
      <Sfx at={61} name="pop-word" volume={0.65} />
      <ExitWhoosh />
      <GhostRows frame={frame} />
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", gap: vertical ? 44 : 18, padding: vertical ? "0 70px" : 0 }}>
        <Interactive.Div
          name="Hook line"
          style={{
            fontSize: vertical ? 104 : 118,
            textAlign: "center",
            lineHeight: 1.05,
            textWrap: "balance",
            fontWeight: 700,
            letterSpacing: "-0.035em",
            color: "white",
            opacity: interpolate(frame, [2, 16], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
            translate: interpolate(frame, [2, 22], ["0px 40px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          You type the same things.
        </Interactive.Div>
        <div style={{ display: "flex", flexDirection: vertical ? "column" : "row", alignItems: "center", gap: vertical ? 6 : 40 }}>
          <Interactive.Div
            name="Every"
            style={{
              fontSize: vertical ? 140 : 118,
              fontWeight: 800,
              letterSpacing: "-0.035em",
              background: "linear-gradient(180deg, #7CC0FF 0%, #1E8BFF 100%)",
              WebkitBackgroundClip: "text",
              color: "transparent",
              opacity: interpolate(frame, [31, 36], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
              scale: interpolate(frame, [31, 43], [1.4, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: Easing.spring({ damping: 14 }),
                output: "perceptual-scale",
              }),
            }}
          >
            Every.
          </Interactive.Div>
          <Interactive.Div
            name="Single"
            style={{
              fontSize: vertical ? 140 : 118,
              fontWeight: 800,
              letterSpacing: "-0.035em",
              background: "linear-gradient(180deg, #7CC0FF 0%, #1E8BFF 100%)",
              WebkitBackgroundClip: "text",
              color: "transparent",
              opacity: interpolate(frame, [47, 52], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
              scale: interpolate(frame, [47, 59], [1.4, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: Easing.spring({ damping: 14 }),
                output: "perceptual-scale",
              }),
            }}
          >
            Single.
          </Interactive.Div>
          <Interactive.Div
            name="Day"
            style={{
              fontSize: vertical ? 140 : 118,
              fontWeight: 800,
              letterSpacing: "-0.035em",
              background: "linear-gradient(180deg, #7CC0FF 0%, #1E8BFF 100%)",
              WebkitBackgroundClip: "text",
              color: "transparent",
              opacity: interpolate(frame, [61, 66], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
              scale: interpolate(frame, [61, 73], [1.4, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: Easing.spring({ damping: 14 }),
                output: "perceptual-scale",
              }),
            }}
          >
            Day.
          </Interactive.Div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
