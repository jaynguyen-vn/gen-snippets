/** Text visible at `frame` when typed from `start`, one character every `perChar` frames. */
export const typedText = (
  text: string,
  frame: number,
  start: number,
  perChar: number,
) => {
  if (frame < start) {
    return "";
  }
  return text.slice(0, Math.floor((frame - start) / perChar) + 1);
};

/** Frame of the most recent keystroke, or null before typing starts. */
export const lastKeyFrame = (
  length: number,
  frame: number,
  start: number,
  perChar: number,
) => {
  if (frame < start) {
    return null;
  }
  return start + Math.min(length - 1, Math.floor((frame - start) / perChar)) * perChar;
};

/**
 * A snippet command being typed, erased with one backspace per frame (the app
 * deletes the trigger with backspaces), then replaced by its expansion.
 * `insertAt` delays the insertion, e.g. while the {{field}} panel is open.
 */
export const expansionAt = (
  command: string,
  frame: number,
  typeStart: number,
  perChar: number,
  eraseStart: number,
  insertAtOverride?: number,
) => {
  const erasedAt = eraseStart + command.length;
  const insertAt = Math.max(erasedAt, insertAtOverride ?? erasedAt);
  if (frame >= insertAt) {
    return { visibleCommand: "", inserted: true, insertAt, lastKey: insertAt };
  }
  if (frame >= erasedAt) {
    return { visibleCommand: "", inserted: false, insertAt, lastKey: erasedAt - 1 };
  }
  if (frame >= eraseStart) {
    return {
      visibleCommand: command.slice(0, command.length - (frame - eraseStart + 1)),
      inserted: false,
      insertAt,
      lastKey: frame,
    };
  }
  return {
    visibleCommand: typedText(command, frame, typeStart, perChar),
    inserted: false,
    insertAt,
    lastKey: lastKeyFrame(command.length, frame, typeStart, perChar),
  };
};
