import React from "react";
import { AbsoluteFill, Easing, Img, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { ExitWhoosh, KeyTaps, Sfx } from "../audio";
import { Caret } from "../components/Caret";
import { KeycapHud } from "../components/KeycapHud";
import { FONT_MONO, FONT_SANS, useVertical } from "../theme";
import { expansionAt } from "../typing";

const TYPE_START = 16;
const PER_CHAR = 5;
const ERASE_START = 29;

/** Cold open: the product's own trick — a short command typed on an empty screen expands into the logo. */
export const IntroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const vertical = useVertical();
  const state = expansionAt(";gs", frame, TYPE_START, PER_CHAR, ERASE_START);

  return (
    <AbsoluteFill style={{ fontFamily: FONT_SANS, justifyContent: "center", alignItems: "center" }}>
      <KeyTaps start={TYPE_START} count={3} perChar={PER_CHAR} volume={0.65} />
      <Sfx at={state.insertAt} name="pop-expand" volume={0.7} />
      <Sfx at={state.insertAt} name="sparkle" volume={0.3} />
      <ExitWhoosh />

      <AbsoluteFill
        style={{
          background: "radial-gradient(circle at 50% 50%, rgba(0, 122, 255, 0.45) 0%, rgba(0, 122, 255, 0) 30%)",
          opacity: interpolate(frame, [32, 36, 70], [0, 1, 0.45], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />

      {state.inserted ? (
        <Interactive.Div
          name="Logo lockup"
          style={{
            display: "flex",
            flexDirection: vertical ? "column" : "row",
            alignItems: "center",
            gap: vertical ? 44 : 40,
            scale: interpolate(frame, [32, 46], [0.82, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.spring({ damping: 12 }),
              output: "perceptual-scale",
            }),
          }}
        >
          <Img
            name="App icon"
            src={staticFile("app-icon.png")}
            style={{
              width: vertical ? 210 : 156,
              height: vertical ? 210 : 156,
              filter: "drop-shadow(0 24px 50px rgba(0, 0, 0, 0.6))",
            }}
          />
          <div
            style={{
              fontSize: vertical ? 132 : 150,
              fontWeight: 800,
              letterSpacing: "-0.045em",
              lineHeight: 1,
              color: "white",
              whiteSpace: "pre",
            }}
          >
            <span
              style={{
                borderRadius: 18,
                padding: "0 0.06em",
                margin: "0 -0.06em",
                background: `rgba(0, 122, 255, ${interpolate(frame, [32, 42, 62], [0.35, 0.28, 0], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                })})`,
              }}
            >
              GenSnippets
            </span>
            <Caret frame={frame} lastKey={state.insertAt} />
          </div>
        </Interactive.Div>
      ) : (
        <div
          style={{
            fontFamily: FONT_MONO,
            fontSize: 120,
            fontWeight: 500,
            color: "white",
            whiteSpace: "pre",
            lineHeight: 1,
          }}
        >
          {state.visibleCommand}
          <Caret frame={frame} lastKey={state.lastKey} />
        </div>
      )}

      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          ...(vertical ? { top: 1200 } : { bottom: 190 }),
          display: "flex",
          justifyContent: "center",
        }}
      >
        <KeycapHud
          frame={frame}
          exitAt={ERASE_START + 2}
          keys={[
            { label: ";", at: TYPE_START },
            { label: "G", at: TYPE_START + PER_CHAR },
            { label: "S", at: TYPE_START + 2 * PER_CHAR },
          ]}
        />
      </div>
    </AbsoluteFill>
  );
};
