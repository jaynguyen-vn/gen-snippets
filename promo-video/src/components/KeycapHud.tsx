import React from "react";
import { Easing } from "remotion";
import { ease, FONT_SANS, POP } from "../theme";

export type Keystroke = { label: string; at: number };

/**
 * On-screen keystroke display. Every key keeps its slot from the start so the
 * HUD never re-centres as keys appear.
 */
export const KeycapHud: React.FC<{
  frame: number;
  keys: Keystroke[];
  exitAt: number;
  size?: number;
  style?: React.CSSProperties;
}> = ({ frame, keys, exitAt, size = 80, style }) => {
  const first = keys[0].at;

  return (
    <div
      style={{
        display: "flex",
        gap: size * 0.18,
        padding: size * 0.18,
        borderRadius: size * 0.38,
        background: "rgba(24, 24, 30, 0.8)",
        border: "1px solid rgba(255, 255, 255, 0.12)",
        boxShadow: "0 24px 60px rgba(0, 0, 0, 0.45)",
        // Arrives with the first key so the pill is never seen empty.
        opacity: ease(frame, [first - 3, first + 1, exitAt, exitAt + 8], [0, 1, 1, 0], Easing.linear),
        scale: ease(frame, [first - 3, first + 4, exitAt, exitAt + 8], [0.9, 1, 1, 0.92]),
        ...style,
      }}
    >
      {keys.map((key) => {
        const shown = frame >= key.at;
        const press = ease(frame, [key.at, key.at + 2, key.at + 7], [0, 1, 0], Easing.linear);
        return (
          <div
            key={`${key.label}-${key.at}`}
            style={{
              minWidth: size,
              height: size,
              padding: `0 ${size * 0.24}px`,
              boxSizing: "border-box",
              borderRadius: size * 0.2,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontFamily: FONT_SANS,
              fontSize: size * 0.46,
              fontWeight: 500,
              color: "white",
              background: "linear-gradient(180deg, #4A4A52 0%, #36363D 100%)",
              boxShadow: `0 ${6 - 4 * press}px 0 #1B1B20, 0 10px 18px rgba(0, 0, 0, 0.35), inset 0 1px 0 rgba(255, 255, 255, 0.16)`,
              translate: `0px ${4 * press}px`,
              opacity: shown ? ease(frame, [key.at, key.at + 4], [0, 1]) : 0,
              scale: shown ? ease(frame, [key.at, key.at + 12], [0.6, 1], POP) : 0.6,
            }}
          >
            {key.label}
          </div>
        );
      })}
    </div>
  );
};
