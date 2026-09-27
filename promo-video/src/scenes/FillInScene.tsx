import React from "react";
import { AbsoluteFill, Easing, Interactive, interpolate, useCurrentFrame } from "remotion";
import { ExitWhoosh, KeyTaps, Sfx } from "../audio";
import { ExpandingText } from "../components/ExpandingText";
import { MacWindow } from "../components/MacWindow";
import { fillTemplate, MetafieldPanel, MetafieldValue } from "../components/MetafieldPanel";
import { SceneCaption } from "../components/SceneCaption";
import { WELCOME_TEMPLATE } from "../snippets";
import { FONT_MONO, FONT_SANS, UI, useVertical } from "../theme";
import { lastKeyFrame, typedText } from "../typing";

const NAME_START = 72;
const COMPANY_START = 92;
const COMPANY_FOCUS = 88;
const INSERT_PRESS = 110;
const INSERTED = 122;

export const FillInScene: React.FC = () => {
  const frame = useCurrentFrame();
  const vertical = useVertical();

  const fields: MetafieldValue[] = [
    {
      key: "name",
      value: typedText("Anna", frame, NAME_START, 3),
      lastKey: lastKeyFrame(4, frame, NAME_START, 3),
    },
    {
      key: "company",
      value: typedText("Acme", frame, COMPANY_START, 3),
      lastKey: lastKeyFrame(4, frame, COMPANY_START, 3) ?? COMPANY_FOCUS,
    },
  ];

  return (
    <AbsoluteFill style={{ fontFamily: FONT_SANS }}>
      <KeyTaps start={22} count={8} perChar={3} />
      <Sfx at={56} name="pop-panel" volume={0.55} />
      <KeyTaps start={NAME_START} count={4} perChar={3} />
      <Sfx at={COMPANY_FOCUS} name="key-hard" volume={0.45} />
      <KeyTaps start={COMPANY_START} count={4} perChar={3} />
      <Sfx at={INSERT_PRESS} name="key-hard" volume={0.5} />
      <Sfx at={INSERTED} name="pop-expand" volume={0.65} />
      <ExitWhoosh />
      <SceneCaption
        frame={frame}
        title="Templates that ask for the details."
        sub={
          <>
            Drop <span style={{ fontFamily: FONT_MONO, color: "#9CCBFF" }}>{"{{fields}}"}</span> into a snippet and fill
            them in as you type.
          </>
        }
      />

      <Interactive.Div
        name="Chat window"
        style={{
          position: "absolute",
          left: vertical ? 60 : 410,
          top: vertical ? 650 : 292,
          opacity: interpolate(frame, [0, 10], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
          translate: interpolate(frame, [0, 22], ["0px 70px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.spring({ damping: 200 }),
          }),
        }}
      >
        <MacWindow width={vertical ? 960 : 1100} height={vertical ? 900 : 560} title="Anna Lee">
          <div
            style={{
              height: "100%",
              boxSizing: "border-box",
              padding: 30,
              display: "flex",
              flexDirection: "column",
              justifyContent: "space-between",
            }}
          >
            <div
              style={{
                alignSelf: "flex-start",
                padding: "16px 24px",
                borderRadius: 26,
                background: "#E9E9EB",
                fontSize: 27,
                color: UI.textPrimary,
              }}
            >
              Hi! We just signed up for the Pro plan.
            </div>
            <div
              style={{
                padding: "16px 26px",
                borderRadius: 30,
                border: "1.5px solid rgba(0, 0, 0, 0.12)",
                fontSize: 27,
                color: UI.textPrimary,
                whiteSpace: "pre",
              }}
            >
              <ExpandingText
                frame={frame}
                command=";welcome"
                expansion={fillTemplate(WELCOME_TEMPLATE, [
                  { key: "name", value: "Anna", lastKey: null },
                  { key: "company", value: "Acme", lastKey: null },
                ])}
                typeStart={22}
                perChar={3}
                eraseStart={47}
                insertAt={INSERTED}
                caret={frame < 56 || frame >= INSERTED}
              />
            </div>
          </div>
        </MacWindow>
      </Interactive.Div>

      <Interactive.Div
        name="Fields panel"
        style={{
          position: "absolute",
          left: vertical ? 65 : 485,
          top: vertical ? 840 : 372,
          opacity: interpolate(frame, [56, 64, 114, 122], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          scale: interpolate(frame, [56, 72, 114, 122], [0.94, 1, 1, 0.96], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.spring({ damping: 14 }),
          }),
        }}
      >
        <MetafieldPanel
          frame={frame}
          zoom={1.9}
          template={WELCOME_TEMPLATE}
          fields={fields}
          focusedIndex={frame >= COMPANY_FOCUS ? 1 : 0}
          insertPressed={frame >= INSERT_PRESS && frame < INSERT_PRESS + 6}
        />
      </Interactive.Div>
    </AbsoluteFill>
  );
};
