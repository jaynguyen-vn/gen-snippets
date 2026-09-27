import React from "react";
import { Easing } from "remotion";
import { ease } from "../theme";
import { expansionAt } from "../typing";
import { Caret } from "./Caret";

/** A trigger typed into a text field that turns into its snippet, with a fading highlight. */
export const ExpandingText: React.FC<{
  frame: number;
  command: string;
  expansion: React.ReactNode;
  typeStart: number;
  perChar: number;
  eraseStart: number;
  insertAt?: number;
  caret?: boolean;
  /** False when the expansion places the caret itself (a {cursor} keyword). */
  caretAfterInsert?: boolean;
  caretColor?: string;
  highlightRgb?: string;
}> = ({
  frame,
  command,
  expansion,
  typeStart,
  perChar,
  eraseStart,
  insertAt,
  caret = true,
  caretAfterInsert = true,
  caretColor,
  highlightRgb = "0, 122, 255",
}) => {
  const state = expansionAt(command, frame, typeStart, perChar, eraseStart, insertAt);
  const glow = ease(
    frame,
    [state.insertAt, state.insertAt + 12, state.insertAt + 50],
    [0.3, 0.24, 0],
    Easing.linear,
  );

  return (
    <>
      {state.inserted ? (
        <span
          style={{
            background: `rgba(${highlightRgb}, ${glow})`,
            borderRadius: 6,
            padding: "0.02em 0.12em",
            margin: "0 -0.12em",
            WebkitBoxDecorationBreak: "clone",
            boxDecorationBreak: "clone",
          }}
        >
          {expansion}
        </span>
      ) : (
        <span>{state.visibleCommand}</span>
      )}
      {caret && (caretAfterInsert || !state.inserted) ? (
        <Caret frame={frame} lastKey={state.lastKey} color={caretColor} />
      ) : null}
    </>
  );
};
