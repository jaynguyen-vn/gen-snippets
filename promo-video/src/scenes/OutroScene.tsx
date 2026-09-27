import React from "react";
import { AbsoluteFill, Easing, Img, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Sfx } from "../audio";
import { FONT_MONO, FONT_SANS, useVertical } from "../theme";

const BADGES = ["Free & open source", "100% offline", "macOS 12+"];

export const OutroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const vertical = useVertical();

  return (
    <AbsoluteFill style={{ fontFamily: FONT_SANS, justifyContent: "center", alignItems: "center" }}>
      <Sfx at={0} name="sparkle" volume={0.5} />
      <AbsoluteFill
        style={{
          background: "radial-gradient(circle at 50% 34%, rgba(0, 122, 255, 0.28) 0%, rgba(0, 122, 255, 0) 32%)",
          opacity: interpolate(frame, [0, 30], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Img
          name="App icon"
          src={staticFile("app-icon.png")}
          style={{
            width: 236,
            height: 236,
            filter: "drop-shadow(0 30px 60px rgba(0, 0, 0, 0.6))",
            opacity: interpolate(frame, [0, 8], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            scale: interpolate(frame, [0, 22], [0.55, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.spring({ damping: 13 }),
              output: "perceptual-scale",
            }),
          }}
        />
        <Interactive.Div
          name="Product name"
          style={{
            marginTop: 40,
            fontSize: 136,
            fontWeight: 800,
            letterSpacing: "-0.045em",
            lineHeight: 1,
            color: "white",
            opacity: interpolate(frame, [8, 20], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            translate: interpolate(frame, [8, 28], ["0px 36px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          GenSnippets
        </Interactive.Div>
        <Interactive.Div
          name="Tagline"
          style={{
            marginTop: 26,
            fontSize: 54,
            fontWeight: 500,
            letterSpacing: "-0.01em",
            color: "rgba(255, 255, 255, 0.75)",
            opacity: interpolate(frame, [16, 28], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            translate: interpolate(frame, [16, 36], ["0px 30px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          Text expansion for your Mac.
        </Interactive.Div>
        <div style={{ marginTop: 52, display: "flex", gap: vertical ? 14 : 20 }}>
          {BADGES.map((badge, index) => (
            <div
              key={badge}
              style={{
                display: "flex",
                alignItems: "center",
                gap: vertical ? 12 : 14,
                padding: vertical ? "12px 22px" : "14px 28px",
                borderRadius: 999,
                fontSize: vertical ? 30 : 34,
                fontWeight: 500,
                color: "white",
                background: "rgba(255, 255, 255, 0.07)",
                border: "1px solid rgba(255, 255, 255, 0.16)",
                opacity: interpolate(frame, [26 + index * 5, 34 + index * 5], [0, 1], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                }),
                translate: interpolate(frame, [26 + index * 5, 42 + index * 5], ["0px 24px", "0px 0px"], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                  easing: Easing.bezier(0.16, 1, 0.3, 1),
                }),
              }}
            >
              <div style={{ width: 12, height: 12, borderRadius: 6, background: "#2F95FF" }} />
              {badge}
            </div>
          ))}
        </div>
        <Interactive.Div
          name="Website"
          style={{
            marginTop: 48,
            fontFamily: FONT_MONO,
            fontSize: vertical ? 42 : 46,
            fontWeight: 600,
            color: "#8EC5FF",
            opacity: interpolate(frame, [44, 56], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            translate: interpolate(frame, [44, 62], ["0px 24px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          gensnippets.lifelonglearning.dev
        </Interactive.Div>
        <Interactive.Div
          name="Source link"
          style={{
            marginTop: 16,
            fontFamily: FONT_MONO,
            fontSize: vertical ? 26 : 28,
            fontWeight: 500,
            color: "rgba(255, 255, 255, 0.55)",
            opacity: interpolate(frame, [52, 64], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
          }}
        >
          Open source · github.com/jaynguyen-vn/gen-snippets
        </Interactive.Div>
      </div>
    </AbsoluteFill>
  );
};
