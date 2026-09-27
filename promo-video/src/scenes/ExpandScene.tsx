import React from "react";
import { AbsoluteFill, Easing, Interactive, interpolate, useCurrentFrame } from "remotion";
import { ExitWhoosh, KeyTaps, Sfx } from "../audio";
import { ExpandingText } from "../components/ExpandingText";
import { PaperPlaneIcon } from "../components/Icons";
import { KeycapHud } from "../components/KeycapHud";
import { MacWindow } from "../components/MacWindow";
import { SceneCaption } from "../components/SceneCaption";
import { SIGNATURE } from "../snippets";
import { FONT_SANS, UI, useVertical } from "../theme";

const HeaderRow: React.FC<{ label: string; children: React.ReactNode }> = ({ label, children }) => (
  <div
    style={{
      height: 60,
      display: "flex",
      alignItems: "center",
      gap: 14,
      padding: "0 36px",
      fontSize: 26,
      borderBottom: "1px solid rgba(0, 0, 0, 0.08)",
    }}
  >
    <span style={{ color: "rgba(0, 0, 0, 0.45)" }}>{label}</span>
    {children}
  </div>
);

export const ExpandScene: React.FC = () => {
  const frame = useCurrentFrame();
  const vertical = useVertical();

  return (
    <AbsoluteFill style={{ fontFamily: FONT_SANS }}>
      <KeyTaps start={30} count={4} perChar={6} volume={0.65} />
      <Sfx at={62} name="pop-expand" volume={0.65} />
      <ExitWhoosh />
      <SceneCaption frame={frame} enterAt={4} exitAt={56} title="Type a short command…" />
      <SceneCaption
        frame={frame}
        enterAt={62}
        title={
          <>
            …get the <span style={{ color: "#5AB0FF" }}>full text</span>. Instantly.
          </>
        }
      />

      <Interactive.Div
        name="Mail window"
        style={{
          position: "absolute",
          left: vertical ? 60 : 370,
          top: vertical ? 520 : 216,
          opacity: interpolate(frame, [0, 10], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
          translate: interpolate(frame, [0, 22], ["0px 70px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.spring({ damping: 200 }),
          }),
        }}
      >
        <MacWindow
          width={vertical ? 960 : 1180}
          height={vertical ? 720 : 640}
          title="New Message"
          accessory={<PaperPlaneIcon size={30} color={UI.accent} />}
        >
          <HeaderRow label="To:">
            <span
              style={{
                padding: "4px 16px",
                borderRadius: 999,
                background: "rgba(0, 122, 255, 0.12)",
                color: UI.accent,
              }}
            >
              Anna Lee
            </span>
          </HeaderRow>
          <HeaderRow label="Subject:">
            <span style={{ color: UI.textPrimary }}>New build ready for review</span>
          </HeaderRow>
          <div
            style={{
              padding: "30px 36px",
              fontSize: 30,
              lineHeight: 1.55,
              color: UI.textPrimary,
              whiteSpace: "pre-wrap",
            }}
          >
            {"Hi Anna,\n\nThe new build is ready for review — let me know what you think.\n\n"}
            <ExpandingText
              frame={frame}
              command=";sig"
              expansion={SIGNATURE}
              typeStart={30}
              perChar={6}
              eraseStart={58}
            />
          </div>
        </MacWindow>
      </Interactive.Div>

      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          ...(vertical ? { top: 1300 } : { bottom: 104 }),
          display: "flex",
          justifyContent: "center",
        }}
      >
        <KeycapHud
          frame={frame}
          exitAt={60}
          keys={[
            { label: ";", at: 30 },
            { label: "S", at: 36 },
            { label: "I", at: 42 },
            { label: "G", at: 48 },
          ]}
        />
      </div>
    </AbsoluteFill>
  );
};
