import React from "react";
import { FONT_SANS, UI } from "../theme";
import { Caret } from "./Caret";

// Redraw of MetafieldInputPanel (MetafieldService.swift) in points; `zoom`
// maps pt to video pixels. The panel asks for every {{field}} before inserting.

export type MetafieldValue = { key: string; value: string; lastKey: number | null };

/** Same rule as the app's live preview: an empty field shows its {{key}}. */
export const fillTemplate = (template: string, fields: MetafieldValue[]) =>
  fields.reduce(
    (text, field) => text.split(`{{${field.key}}}`).join(field.value === "" ? `{{${field.key}}}` : field.value),
    template,
  );

const Button: React.FC<{ label: string; primary?: boolean; pressed?: boolean }> = ({
  label,
  primary = false,
  pressed = false,
}) => (
  <div
    style={{
      width: 80,
      height: 22,
      borderRadius: 6,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: 13,
      color: primary ? "white" : UI.textPrimary,
      background: primary ? (pressed ? UI.accentPressed : UI.accent) : "white",
      border: primary ? "none" : "0.5px solid rgba(0, 0, 0, 0.2)",
      boxShadow: "0 0.5px 1px rgba(0, 0, 0, 0.15)",
      scale: pressed ? 0.96 : 1,
    }}
  >
    {label}
  </div>
);

const Separator: React.FC = () => <div style={{ height: 1, background: "rgba(0, 0, 0, 0.1)" }} />;

export const MetafieldPanel: React.FC<{
  frame: number;
  zoom: number;
  template: string;
  fields: MetafieldValue[];
  focusedIndex: number;
  insertPressed: boolean;
}> = ({ frame, zoom, template, fields, focusedIndex, insertPressed }) => (
  <div
    style={{
      zoom,
      width: 500,
      borderRadius: 10,
      overflow: "hidden",
      fontFamily: FONT_SANS,
      background: UI.windowBackground,
      boxShadow: "0 20px 50px rgba(0, 0, 0, 0.4), 0 6px 16px rgba(0, 0, 0, 0.2)",
      outline: "0.5px solid rgba(0, 0, 0, 0.25)",
    }}
  >
    <div
      style={{
        height: 24,
        display: "flex",
        alignItems: "center",
        padding: "0 8px",
        background: "#E7E7E7",
        borderBottom: "1px solid rgba(0, 0, 0, 0.06)",
      }}
    >
      <div
        style={{
          width: 12,
          height: 12,
          borderRadius: 6,
          background: "#FF5F57",
          boxShadow: "inset 0 0 0 0.5px rgba(0, 0, 0, 0.15)",
        }}
      />
    </div>
    <div style={{ padding: 16 }}>
      {fields.map((field, index) => (
        <div
          key={field.key}
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            marginBottom: index < fields.length - 1 ? 12 : 0,
          }}
        >
          <div style={{ width: 100, textAlign: "right", fontSize: 13, color: UI.textPrimary }}>{field.key}:</div>
          <div
            style={{
              width: 360,
              height: 24,
              boxSizing: "border-box",
              padding: "0 6px",
              display: "flex",
              alignItems: "center",
              borderRadius: 6,
              background: "white",
              fontSize: 13,
              color: UI.textPrimary,
              whiteSpace: "pre",
              border: "0.5px solid rgba(0, 0, 0, 0.22)",
              boxShadow:
                index === focusedIndex
                  ? "0 0 0 3.5px rgba(0, 122, 255, 0.45)"
                  : "inset 0 0.5px 1px rgba(0, 0, 0, 0.08)",
            }}
          >
            {field.value}
            {index === focusedIndex ? <Caret frame={frame} lastKey={field.lastKey} color={UI.textPrimary} /> : null}
          </div>
        </div>
      ))}
      <div style={{ height: 16 }} />
      <Separator />
      <div style={{ height: 8 }} />
      <div style={{ height: 16, lineHeight: "16px", fontSize: 11, fontWeight: 500, color: UI.textSecondary }}>
        Preview:
      </div>
      <div style={{ height: 4 }} />
      <div
        style={{
          minHeight: 60,
          boxSizing: "border-box",
          padding: 6,
          border: "1px solid rgba(0, 0, 0, 0.18)",
          background: UI.controlBackground,
          fontSize: 12,
          lineHeight: 1.4,
          color: UI.textPrimary,
        }}
      >
        {fillTemplate(template, fields)}
      </div>
      <div style={{ height: 12 }} />
      <Separator />
      <div style={{ height: 12 }} />
      <div style={{ height: 28, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <Button label="Cancel" />
        <Button label="Insert" primary pressed={insertPressed} />
      </div>
    </div>
  </div>
);
