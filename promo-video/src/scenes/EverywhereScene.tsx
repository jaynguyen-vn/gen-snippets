import React from "react";
import { AbsoluteFill, Easing, Interactive, interpolate, useCurrentFrame } from "remotion";
import { ExitWhoosh, KeyTaps, Sfx } from "../audio";
import { Caret } from "../components/Caret";
import { ExpandingText } from "../components/ExpandingText";
import { MacWindow } from "../components/MacWindow";
import { SceneCaption } from "../components/SceneCaption";
import { ease, FONT_MONO, FONT_SANS, POP, UI, useVertical } from "../theme";

const CODE = {
  plain: "#E6EDF3",
  keyword: "#FF7B72",
  fn: "#D2A8FF",
  string: "#A5D6FF",
  gutter: "#5C6370",
};

/** Keyword chip that pops in when its snippet expands: under the window in 16:9, pinned to its corner in 9:16. */
const KeywordChip: React.FC<{ frame: number; at: number; children: React.ReactNode }> = ({
  frame,
  at,
  children,
}) => {
  const vertical = useVertical();
  return (
    <div
      style={{
        padding: "10px 24px",
        borderRadius: 999,
        fontFamily: FONT_MONO,
        fontSize: 30,
        fontWeight: 500,
        color: "#9CCBFF",
        background: vertical ? "#0E1B30" : "rgba(0, 122, 255, 0.14)",
        border: vertical ? "1.5px solid rgba(90, 176, 255, 0.6)" : "1px solid rgba(90, 176, 255, 0.35)",
        boxShadow: vertical ? "0 10px 24px rgba(0, 0, 0, 0.35)" : "none",
        ...(vertical ? { position: "absolute", top: -26, right: 28 } : {}),
        opacity: ease(frame, [at, at + 6], [0, 1], Easing.linear),
        scale: ease(frame, [at, at + 14], [0.6, 1], POP),
      }}
    >
      {children}
    </div>
  );
};

const CodeLine: React.FC<{ n: number; children?: React.ReactNode }> = ({ n, children }) => (
  <div style={{ display: "flex", whiteSpace: "pre" }}>
    <div style={{ width: 56, textAlign: "right", color: CODE.gutter, flexShrink: 0 }}>{n}</div>
    <div style={{ paddingLeft: 22, color: CODE.plain }}>{children}</div>
  </div>
);

export const EverywhereScene: React.FC = () => {
  const frame = useCurrentFrame();
  const vertical = useVertical();
  const windowWidth = vertical ? 960 : 540;
  const windowHeight = vertical ? 318 : 500;

  return (
    <AbsoluteFill style={{ fontFamily: FONT_SANS }}>
      <KeyTaps start={30} count={5} perChar={3} />
      <Sfx at={53} name="pop-expand" volume={0.5} />
      <KeyTaps start={58} count={4} perChar={3} />
      <Sfx at={78} name="pop-expand" volume={0.5} />
      <KeyTaps start={90} count={5} perChar={3} />
      <Sfx at={111} name="pop-expand" volume={0.5} />
      <ExitWhoosh />
      <SceneCaption
        frame={frame}
        title="Works in every app."
        sub="Live keywords fill in the date, the time, your clipboard…"
      />

      <div
        style={{
          position: "absolute",
          top: vertical ? 575 : 296,
          left: 0,
          right: 0,
          display: "flex",
          flexDirection: vertical ? "column" : "row",
          alignItems: "center",
          justifyContent: "center",
          gap: vertical ? 36 : 40,
        }}
      >
        <Interactive.Div
          name="Notes window"
          style={{
            position: "relative",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 34,
            opacity: interpolate(frame, [6, 14], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            translate: interpolate(frame, [6, 26], ["0px 80px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.spring({ damping: 200 }),
            }),
          }}
        >
          <MacWindow width={windowWidth} height={windowHeight} title="Notes">
            <div style={{ padding: vertical ? "24px 36px" : "34px 36px", color: UI.textPrimary }}>
              <div style={{ fontSize: 36, fontWeight: 700, letterSpacing: "-0.01em", whiteSpace: "pre" }}>
                {"Standup · "}
                <ExpandingText
                  frame={frame}
                  command=";date"
                  expansion="27/09/2026"
                  typeStart={30}
                  perChar={3}
                  eraseStart={48}
                  caret={frame < 58}
                />
              </div>
              <div style={{ marginTop: 22, fontSize: 27, lineHeight: 1.75, color: "rgba(0, 0, 0, 0.62)" }}>
                <div>• Ship the onboarding flow</div>
                <div>• Review the Q4 roadmap</div>
                <div>• Fix the flaky login test</div>
              </div>
            </div>
          </MacWindow>
          <KeywordChip frame={frame} at={53}>
            {"{dd/mm/yyyy}"}
          </KeywordChip>
        </Interactive.Div>

        <Interactive.Div
          name="Code window"
          style={{
            position: "relative",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 34,
            opacity: interpolate(frame, [12, 20], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            translate: interpolate(frame, [12, 32], ["0px 80px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.spring({ damping: 200 }),
            }),
          }}
        >
          <MacWindow width={windowWidth} height={windowHeight} title="deploy.js" dark>
            <div style={{ padding: vertical ? "22px 0" : "28px 0", fontFamily: FONT_MONO, fontSize: 23, lineHeight: 1.8 }}>
              <CodeLine n={1}>
                <span style={{ color: CODE.keyword }}>function</span> <span style={{ color: CODE.fn }}>deploy</span>
                (env) {"{"}
              </CodeLine>
              <CodeLine n={2}>
                {"  "}
                <span style={{ color: CODE.fn }}>build</span>(env);
              </CodeLine>
              <CodeLine n={3}>
                {"  "}
                <ExpandingText
                  frame={frame}
                  command=";log"
                  expansion={
                    <>
                      console.<span style={{ color: CODE.fn }}>log</span>(
                      <span style={{ color: CODE.string }}>
                        &quot;[14:32:05] <Caret frame={frame} lastKey={78} visible={frame < 88} />
                        &quot;
                      </span>
                      );
                    </>
                  }
                  typeStart={58}
                  perChar={3}
                  eraseStart={74}
                  caret={frame >= 54 && frame < 88}
                  caretAfterInsert={false}
                  highlightRgb="90, 176, 255"
                />
              </CodeLine>
              <CodeLine n={4}>{"}"}</CodeLine>
            </div>
          </MacWindow>
          <KeywordChip frame={frame} at={78}>
            {"{time} {cursor}"}
          </KeywordChip>
        </Interactive.Div>

        <Interactive.Div
          name="Chat window"
          style={{
            position: "relative",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 34,
            opacity: interpolate(frame, [18, 26], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            translate: interpolate(frame, [18, 38], ["0px 80px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.spring({ damping: 200 }),
            }),
          }}
        >
          <MacWindow width={windowWidth} height={windowHeight} title="Chat">
            <div
              style={{
                height: "100%",
                boxSizing: "border-box",
                padding: vertical ? "18px 26px" : 26,
                display: "flex",
                flexDirection: "column",
                justifyContent: "space-between",
              }}
            >
              <div>
                <div style={{ fontSize: 20, color: UI.textSecondary, marginBottom: 8, marginLeft: 6 }}>Sam</div>
                <div
                  style={{
                    display: "inline-block",
                    padding: "14px 20px",
                    borderRadius: 24,
                    background: "#E9E9EB",
                    fontSize: 25,
                    lineHeight: 1.35,
                    color: UI.textPrimary,
                  }}
                >
                  Can you send me the roadmap doc?
                </div>
              </div>
              <div
                style={{
                  padding: "14px 22px",
                  borderRadius: 26,
                  border: "1.5px solid rgba(0, 0, 0, 0.12)",
                  fontSize: 25,
                  color: UI.textPrimary,
                  whiteSpace: "pre",
                }}
              >
                <ExpandingText
                  frame={frame}
                  command=";link"
                  expansion="Sure: https://example.com/q4"
                  typeStart={90}
                  perChar={3}
                  eraseStart={106}
                  caret={frame >= 86}
                />
              </div>
            </div>
          </MacWindow>
          <KeywordChip frame={frame} at={111}>
            {"{clipboard}"}
          </KeywordChip>
        </Interactive.Div>
      </div>
    </AbsoluteFill>
  );
};
