import React from "react";
import { Easing } from "remotion";
import { searchSnippets, Snippet } from "../snippets";
import { ease, FONT_MONO, FONT_ROUNDED, FONT_SANS, POP, UI } from "../theme";
import { Caret } from "./Caret";
import { CheckCircleIcon, ClearIcon, SearchIcon, TextInsertIcon } from "./Icons";

// Redraw of ModernSnippetSearchView in points; `zoom` maps pt to video pixels.

const ShortcutBadge: React.FC<{ label: string }> = ({ label }) => (
  <div
    style={{
      fontSize: 11,
      fontWeight: 500,
      color: UI.textSecondary,
      padding: "2px 4px",
      borderRadius: 4,
      background: UI.surfaceSecondary,
      border: `0.5px solid ${UI.borderSubtle}`,
    }}
  >
    {label}
  </div>
);

const Hint: React.FC<{ badge: string; label: string }> = ({ badge, label }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
    <ShortcutBadge label={badge} />
    <div style={{ fontSize: 11, color: UI.textTertiary }}>{label}</div>
  </div>
);

const Row: React.FC<{ snippet: Snippet; selected: boolean; inserted: number }> = ({
  snippet,
  selected,
  inserted,
}) => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      gap: 12,
      padding: "8px 12px",
      borderRadius: 8,
      background: selected ? UI.selectedBackground : "transparent",
      boxShadow: selected ? "inset 0 0 0 2px rgba(0, 122, 255, 0.4)" : "none",
    }}
  >
    <div
      style={{
        width: 36,
        height: 36,
        flexShrink: 0,
        borderRadius: 18,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: selected ? "rgba(0, 122, 255, 0.2)" : UI.surfaceSecondary,
        fontFamily: FONT_ROUNDED,
        fontSize: 14,
        fontWeight: selected ? 700 : 600,
        color: selected ? UI.accent : UI.textSecondary,
      }}
    >
      {snippet.command.slice(0, 1).toUpperCase()}
    </div>
    <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
      <div style={{ fontSize: 13, fontWeight: 500, color: UI.textPrimary }}>{snippet.command}</div>
      <div style={{ fontSize: 11, color: UI.textSecondary }}>{snippet.description}</div>
    </div>
    <div style={{ flex: 1 }} />
    {inserted > 0 ? (
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 4,
          color: UI.success,
          fontSize: 11,
          fontWeight: 500,
          opacity: inserted,
          scale: inserted,
        }}
      >
        <CheckCircleIcon size={12} color={UI.success} />
        Inserted
      </div>
    ) : null}
  </div>
);

const Detail: React.FC<{ snippet: Snippet }> = ({ snippet }) => (
  <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 16,
        padding: "20px 24px",
        background: UI.windowBackground,
      }}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        <div style={{ fontSize: 18, fontWeight: 600, color: UI.textPrimary }}>{snippet.command}</div>
        <div style={{ fontSize: 11, color: UI.textSecondary }}>{snippet.description}</div>
      </div>
      <div style={{ flex: 1 }} />
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 6,
          padding: "8px 16px",
          borderRadius: 6,
          background: UI.accent,
          color: "white",
          fontSize: 13,
          fontWeight: 500,
        }}
      >
        <TextInsertIcon size={14} color="white" />
        Insert
      </div>
    </div>
    <div style={{ height: 1, background: UI.border }} />
    <div style={{ flex: 1, padding: 20, background: UI.textBackground }}>
      <div
        style={{
          padding: 16,
          borderRadius: 8,
          background: UI.surfaceSecondary,
          border: `1px solid ${UI.borderSubtle}`,
          fontFamily: FONT_MONO,
          fontSize: 13,
          fontWeight: 500,
          lineHeight: 1.5,
          color: "rgba(0, 0, 0, 0.77)",
          whiteSpace: "pre-wrap",
        }}
      >
        {snippet.content}
      </div>
    </div>
  </div>
);

export const SearchPanel: React.FC<{
  frame: number;
  zoom: number;
  query: string;
  lastKey: number | null;
  insertedAt: number | null;
  height?: number;
}> = ({ frame, zoom, query, lastKey, insertedAt, height = 520 }) => {
  const results = searchSnippets(query);
  const inserted =
    insertedAt === null ? 0 : ease(frame, [insertedAt, insertedAt + 10], [0, 1], POP);

  return (
    <div
      style={{
        zoom,
        width: 860,
        height,
        borderRadius: 10,
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        fontFamily: FONT_SANS,
        background: "#EDEDED",
        boxShadow: "0 15px 30px rgba(0, 0, 0, 0.15), 0 30px 70px rgba(0, 0, 0, 0.45)",
        outline: "1px solid rgba(255, 255, 255, 0.12)",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 12,
          padding: "16px 20px",
          background: UI.windowBackground,
        }}
      >
        <div
          style={{
            width: 380,
            display: "flex",
            alignItems: "center",
            gap: 8,
            padding: "8px 12px",
            borderRadius: 8,
            background: UI.controlBackground,
            border: `1px solid ${UI.borderSubtle}`,
          }}
        >
          <SearchIcon size={16} color={UI.textTertiary} />
          <div style={{ flex: 1, fontSize: 14, color: UI.textPrimary, whiteSpace: "pre" }}>
            {query === "" ? (
              <>
                <Caret frame={frame} lastKey={lastKey} color={UI.textPrimary} />
                <span style={{ color: UI.placeholder }}>Search snippets...</span>
              </>
            ) : (
              <>
                {query}
                <Caret frame={frame} lastKey={lastKey} color={UI.textPrimary} />
              </>
            )}
          </div>
          {query !== "" ? <ClearIcon size={14} color={UI.textTertiary} /> : null}
        </div>
        <div style={{ flex: 1 }} />
        {query !== "" ? (
          <div style={{ fontSize: 11, fontWeight: 500, color: UI.textTertiary }}>
            {results.length} result{results.length === 1 ? "" : "s"}
          </div>
        ) : null}
        <div style={{ display: "flex", gap: 12 }}>
          <Hint badge="Enter" label="Insert" />
          <Hint badge="Esc" label="Close" />
        </div>
      </div>
      <div style={{ height: 1, background: UI.border }} />
      <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
        <div
          style={{
            width: 360,
            flexShrink: 0,
            padding: 8,
            display: "flex",
            flexDirection: "column",
            gap: 2,
            overflow: "hidden",
            background: UI.surfaceSecondary,
          }}
        >
          {results.map((snippet, index) => (
            <Row
              key={snippet.command}
              snippet={snippet}
              selected={index === 0}
              inserted={index === 0 ? inserted : 0}
            />
          ))}
        </div>
        <div style={{ width: 1, background: UI.border }} />
        {results.length > 0 ? <Detail snippet={results[0]} /> : null}
      </div>
    </div>
  );
};

/** Fade-and-lift used when a panel pops up; exported so scenes share one feel. */
export const panelEntrance = (frame: number, at: number) => ({
  opacity: ease(frame, [at, at + 8], [0, 1], Easing.linear),
  scale: ease(frame, [at, at + 16], [0.94, 1], POP),
});
