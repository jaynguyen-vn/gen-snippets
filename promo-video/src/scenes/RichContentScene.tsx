import React from "react";
import { AbsoluteFill, Easing, Img, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { ExitWhoosh, KeyTaps, Sfx } from "../audio";
import { Caret } from "../components/Caret";
import { MacWindow } from "../components/MacWindow";
import { SceneCaption } from "../components/SceneCaption";
import { ease, FONT_SANS, POP, UI, useVertical } from "../theme";
import { expansionAt } from "../typing";

// Image and file snippets. The app pastes an image, or a file URL, into the
// focused field; in a chat app that lands as an attachment you then send.

const QR = { typeStart: 24, perChar: 4, eraseStart: 36, send: 50 };
const GUIDE = { typeStart: 66, perChar: 3, eraseStart: 85, send: 104 };

/** QR code to the product site, with the app icon in the middle (level-H error correction). */
const QrCard: React.FC<{ size: number }> = ({ size }) => (
  <div
    style={{
      width: size,
      height: size,
      boxSizing: "border-box",
      padding: size * 0.08,
      borderRadius: size * 0.08,
      background: "white",
      position: "relative",
      boxShadow: "0 6px 18px rgba(0, 0, 0, 0.12), 0 0 0 1px rgba(0, 0, 0, 0.06)",
    }}
  >
    <Img src={staticFile("qr-gensnippets.svg")} style={{ width: "100%", height: "100%", display: "block" }} />
    <Img
      src={staticFile("app-icon.png")}
      style={{
        position: "absolute",
        width: size * 0.2,
        height: size * 0.2,
        left: size * 0.4,
        top: size * 0.4,
        borderRadius: size * 0.04,
        outline: `${size * 0.015}px solid white`,
      }}
    />
  </div>
);

const PdfIcon: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size * 0.8} height={size} viewBox="0 0 40 50">
    <path d="M4 2h22l12 12v32a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z" fill="#F4F4F6" stroke="#C9C9CF" strokeWidth="1.5" />
    <path d="M26 2v10a2 2 0 0 0 2 2h10" fill="#E2E2E7" stroke="#C9C9CF" strokeWidth="1.5" />
    <rect x="0" y="27" width="30" height="14" rx="3" fill="#E5484D" />
    <text x="15" y="37.5" textAnchor="middle" fontFamily={FONT_SANS} fontSize="10" fontWeight="700" fill="white">
      PDF
    </text>
  </svg>
);

const FileRow: React.FC<{ scale: number }> = ({ scale }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 16 * scale }}>
    <PdfIcon size={56 * scale} />
    <div style={{ display: "flex", flexDirection: "column", gap: 4 * scale }}>
      <div style={{ fontSize: 25 * scale, fontWeight: 600, color: UI.textPrimary }}>Quick-Start-Guide.pdf</div>
      <div style={{ fontSize: 20 * scale, color: UI.textSecondary }}>PDF · 1.2 MB</div>
    </div>
  </div>
);

export const RichContentScene: React.FC = () => {
  const frame = useCurrentFrame();
  const vertical = useVertical();
  const qr = expansionAt(";qr", frame, QR.typeStart, QR.perChar, QR.eraseStart);
  const guide = expansionAt(";guide", frame, GUIDE.typeStart, GUIDE.perChar, GUIDE.eraseStart);

  const qrSent = frame >= QR.send;
  const guideSent = frame >= GUIDE.send;
  const typingGuide = frame >= GUIDE.typeStart;

  // What sits in the composer right now.
  let composer: React.ReactNode;
  if (!qrSent) {
    composer = qr.inserted ? (
      <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
        <div style={{ scale: ease(frame, [qr.insertAt, qr.insertAt + 12], [0.6, 1], POP) }}>
          <QrCard size={vertical ? 100 : 88} />
        </div>
        <Caret frame={frame} lastKey={qr.insertAt} />
      </div>
    ) : (
      <>
        {qr.visibleCommand}
        <Caret frame={frame} lastKey={qr.lastKey} />
      </>
    );
  } else if (!guideSent) {
    composer =
      typingGuide && guide.inserted ? (
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <div
            style={{
              padding: "10px 16px",
              borderRadius: 14,
              background: "#F2F2F5",
              border: "1px solid rgba(0, 0, 0, 0.08)",
              scale: ease(frame, [guide.insertAt, guide.insertAt + 12], [0.6, 1], POP),
            }}
          >
            <FileRow scale={vertical ? 0.9 : 0.8} />
          </div>
          <Caret frame={frame} lastKey={guide.insertAt} />
        </div>
      ) : (
        <>
          {typingGuide ? guide.visibleCommand : ""}
          <Caret frame={frame} lastKey={typingGuide ? guide.lastKey : QR.send} />
        </>
      );
  } else {
    composer = <Caret frame={frame} lastKey={GUIDE.send} />;
  }

  return (
    <AbsoluteFill style={{ fontFamily: FONT_SANS }}>
      <KeyTaps start={QR.typeStart} count={3} perChar={QR.perChar} />
      <Sfx at={qr.insertAt} name="pop-expand" volume={0.6} />
      <Sfx at={QR.send} name="key-hard" volume={0.5} />
      <Sfx at={QR.send + 2} name="pop-panel" volume={0.45} />
      <KeyTaps start={GUIDE.typeStart} count={6} perChar={GUIDE.perChar} />
      <Sfx at={guide.insertAt} name="pop-expand" volume={0.6} />
      <Sfx at={GUIDE.send} name="key-hard" volume={0.5} />
      <Sfx at={GUIDE.send + 2} name="pop-panel" volume={0.45} />
      <ExitWhoosh />

      <SceneCaption
        frame={frame}
        title="Images and files, too."
        sub={
          <>
            Send a <span style={{ color: "#9CCBFF" }}>QR code</span> or a <span style={{ color: "#9CCBFF" }}>PDF</span>{" "}
            with one short command.
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
        <MacWindow width={vertical ? 960 : 1100} height={vertical ? 950 : 640} title="Sam">
          <div
            style={{
              height: "100%",
              boxSizing: "border-box",
              padding: "0 30px 26px",
              display: "flex",
              flexDirection: "column",
            }}
          >
            {/* Thread, anchored to the composer so new messages push older ones up. */}
            <div
              style={{
                flex: 1,
                display: "flex",
                flexDirection: "column",
                justifyContent: "flex-end",
                gap: 16,
                overflow: "hidden",
                paddingBottom: 18,
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
                Where can I get the app? Any quick-start guide?
              </div>
              {qrSent ? (
                <div
                  style={{
                    alignSelf: "flex-end",
                    opacity: ease(frame, [QR.send, QR.send + 6], [0, 1], Easing.linear),
                    translate: `0px ${ease(frame, [QR.send, QR.send + 14], [40, 0])}px`,
                  }}
                >
                  <QrCard size={vertical ? 300 : 236} />
                </div>
              ) : null}
              {guideSent ? (
                <div
                  style={{
                    alignSelf: "flex-end",
                    padding: "16px 22px",
                    borderRadius: 22,
                    background: "#DCEBFF",
                    opacity: ease(frame, [GUIDE.send, GUIDE.send + 6], [0, 1], Easing.linear),
                    translate: `0px ${ease(frame, [GUIDE.send, GUIDE.send + 14], [40, 0])}px`,
                  }}
                >
                  <FileRow scale={vertical ? 1.1 : 1} />
                </div>
              ) : null}
            </div>
            <div
              style={{
                minHeight: 64,
                boxSizing: "border-box",
                padding: "12px 24px",
                borderRadius: 32,
                border: "1.5px solid rgba(0, 0, 0, 0.12)",
                display: "flex",
                alignItems: "center",
                fontSize: 27,
                color: UI.textPrimary,
                whiteSpace: "pre",
              }}
            >
              {composer}
            </div>
          </div>
        </MacWindow>
      </Interactive.Div>
    </AbsoluteFill>
  );
};
