import React from "react";
import { UI } from "../theme";

/** Text insertion point: solid while typing, blinking when idle. Sized in em. */
export const Caret: React.FC<{
  frame: number;
  lastKey: number | null;
  color?: string;
  visible?: boolean;
}> = ({ frame, lastKey, color = UI.accent, visible = true }) => {
  const typingRecently = lastKey !== null && frame >= lastKey && frame - lastKey < 14;
  const blinkOn = Math.floor(frame / 16) % 2 === 0;
  return (
    <span
      style={{
        display: "inline-block",
        width: "0.085em",
        minWidth: 2,
        height: "1.15em",
        marginLeft: "0.04em",
        verticalAlign: "-0.2em",
        borderRadius: 2,
        background: color,
        opacity: visible && (typingRecently || blinkOn) ? 1 : 0,
      }}
    />
  );
};
