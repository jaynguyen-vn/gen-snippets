import React from "react";
import { FONT_SANS } from "../theme";

const TRAFFIC_LIGHTS = ["#FF5F57", "#FEBC2E", "#28C840"];

/** Generic macOS window chrome at video scale (not pt). */
export const MacWindow: React.FC<{
  width: number;
  height: number;
  title?: string;
  dark?: boolean;
  accessory?: React.ReactNode;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ width, height, title, dark = false, accessory, children, style }) => (
  <div
    style={{
      width,
      height,
      borderRadius: 22,
      overflow: "hidden",
      display: "flex",
      flexDirection: "column",
      fontFamily: FONT_SANS,
      background: dark ? "#1D1E22" : "#FFFFFF",
      boxShadow:
        "0 50px 120px rgba(0, 0, 0, 0.55), 0 14px 34px rgba(0, 0, 0, 0.35), 0 0 0 1px rgba(255, 255, 255, 0.1)",
      ...style,
    }}
  >
    <div
      style={{
        height: 56,
        flexShrink: 0,
        position: "relative",
        display: "flex",
        alignItems: "center",
        padding: "0 22px",
        background: dark ? "#2A2B30" : "#F3F3F3",
        borderBottom: dark ? "1px solid rgba(255, 255, 255, 0.06)" : "1px solid rgba(0, 0, 0, 0.08)",
      }}
    >
      <div style={{ display: "flex", gap: 12 }}>
        {TRAFFIC_LIGHTS.map((color) => (
          <div
            key={color}
            style={{
              width: 20,
              height: 20,
              borderRadius: 10,
              background: color,
              boxShadow: "inset 0 0 0 1px rgba(0, 0, 0, 0.12)",
            }}
          />
        ))}
      </div>
      {title ? (
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            textAlign: "center",
            fontSize: 22,
            fontWeight: 600,
            color: dark ? "rgba(255, 255, 255, 0.78)" : "rgba(0, 0, 0, 0.72)",
          }}
        >
          {title}
        </div>
      ) : null}
      {accessory ? <div style={{ marginLeft: "auto", position: "relative" }}>{accessory}</div> : null}
    </div>
    <div style={{ flex: 1, position: "relative", overflow: "hidden" }}>{children}</div>
  </div>
);
