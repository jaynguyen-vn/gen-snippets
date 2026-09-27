import React from "react";
import { AbsoluteFill, Easing, Interactive, interpolate, useCurrentFrame } from "remotion";
import { KeyTaps, Sfx } from "../audio";
import { ExpandingText } from "../components/ExpandingText";
import { KeycapHud } from "../components/KeycapHud";
import { MacWindow } from "../components/MacWindow";
import { SceneCaption } from "../components/SceneCaption";
import { SearchPanel } from "../components/SearchPanel";
import { SNIPPETS } from "../snippets";
import { FONT_SANS, UI, useVertical } from "../theme";
import { lastKeyFrame, typedText } from "../typing";

const QUERY_START = 58;
const ENTER = 90;
const INSERTED = 112;

const HOME_ADDRESS = SNIPPETS.find((s) => s.command === ";addr")?.content ?? "";

export const QuickSearchScene: React.FC = () => {
  const frame = useCurrentFrame();
  const vertical = useVertical();

  return (
    <AbsoluteFill style={{ fontFamily: FONT_SANS }}>
      <Sfx at={12} name="key-hard" volume={0.5} />
      <Sfx at={16} name="key-hard" volume={0.5} />
      <Sfx at={20} name="key-hard" volume={0.6} />
      <Sfx at={34} name="pop-panel" volume={0.55} />
      <KeyTaps start={QUERY_START} count={4} perChar={4} />
      <Sfx at={ENTER} name="key-hard" volume={0.6} />
      <Sfx at={INSERTED} name="pop-expand" volume={0.65} />
      {/* No exit whoosh: the outro opens with its own sparkle. */}
      <SceneCaption frame={frame} title="Every snippet, one shortcut away." />

      <Interactive.Div
        name="Checkout window"
        style={{
          position: "absolute",
          left: vertical ? 60 : 360,
          top: vertical ? 600 : 262,
          opacity: interpolate(frame, [0, 10], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
          translate: interpolate(frame, [0, 22], ["0px 70px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.spring({ damping: 200 }),
          }),
        }}
      >
        <MacWindow width={vertical ? 960 : 1200} height={vertical ? 640 : 580} title="Checkout">
          <div style={{ padding: "40px 52px", display: "flex", flexDirection: "column", gap: 22 }}>
            <div style={{ fontSize: 36, fontWeight: 700, color: UI.textPrimary }}>Shipping address</div>
            <div
              style={{
                height: 210,
                boxSizing: "border-box",
                padding: "20px 24px",
                borderRadius: 14,
                border: "1.5px solid rgba(0, 122, 255, 0.55)",
                boxShadow: "0 0 0 5px rgba(0, 122, 255, 0.14)",
                fontSize: 30,
                lineHeight: 1.5,
                color: UI.textPrimary,
                whiteSpace: "pre-wrap",
              }}
            >
              <ExpandingText
                frame={frame}
                command=""
                expansion={HOME_ADDRESS}
                typeStart={0}
                perChar={1}
                eraseStart={INSERTED}
              />
            </div>
            <div
              style={{
                alignSelf: "flex-end",
                marginTop: 8,
                padding: "16px 32px",
                borderRadius: 12,
                background: UI.accent,
                color: "white",
                fontSize: 27,
                fontWeight: 600,
              }}
            >
              Continue to payment
            </div>
          </div>
        </MacWindow>
      </Interactive.Div>

      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", top: 60 }}>
        <KeycapHud
          frame={frame}
          size={130}
          exitAt={32}
          keys={[
            { label: "⌘", at: 12 },
            { label: "⌥", at: 16 },
            { label: "E", at: 20 },
          ]}
        />
      </AbsoluteFill>

      <Interactive.Div
        name="Search panel"
        style={{
          position: "absolute",
          left: vertical ? 40 : 315,
          top: vertical ? 540 : 224,
          opacity: interpolate(frame, [34, 42, 102, 110], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          scale: interpolate(frame, [34, 52, 102, 110], [0.94, 1, 1, 0.96], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.spring({ damping: 14 }),
          }),
        }}
      >
        <SearchPanel
          frame={frame}
          zoom={vertical ? 1.6 : 1.5}
          height={500}
          query={typedText("addr", frame, QUERY_START, 4)}
          lastKey={lastKeyFrame(4, frame, QUERY_START, 4)}
          insertedAt={frame >= ENTER ? ENTER : null}
        />
      </Interactive.Div>
    </AbsoluteFill>
  );
};
