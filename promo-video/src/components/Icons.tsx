import React from "react";

// Hand-drawn stand-ins for the SF Symbols the app uses.

type IconProps = { size: number; color: string };

export const SearchIcon: React.FC<IconProps> = ({ size, color }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <circle cx="10.5" cy="10.5" r="6.5" stroke={color} strokeWidth="2.2" />
    <path d="M15.5 15.5L20.5 20.5" stroke={color} strokeWidth="2.2" strokeLinecap="round" />
  </svg>
);

export const ClearIcon: React.FC<IconProps> = ({ size, color }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <circle cx="12" cy="12" r="11" fill={color} />
    <path d="M8.5 8.5L15.5 15.5M15.5 8.5L8.5 15.5" stroke="white" strokeWidth="2.2" strokeLinecap="round" />
  </svg>
);

export const CheckCircleIcon: React.FC<IconProps> = ({ size, color }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <circle cx="12" cy="12" r="11" fill={color} />
    <path
      d="M7 12.5L10.5 16L17 8.5"
      stroke="white"
      strokeWidth="2.4"
      strokeLinecap="round"
      strokeLinejoin="round"
      fill="none"
    />
  </svg>
);

export const TextInsertIcon: React.FC<IconProps> = ({ size, color }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M10 5H21M10 12H21M3 19H21" stroke={color} strokeWidth="2.2" strokeLinecap="round" />
    <path d="M3 8.5L6.5 12L3 15.5" stroke={color} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const PaperPlaneIcon: React.FC<IconProps> = ({ size, color }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path
      d="M21 3L10 14M21 3L14.5 21L10 14M21 3L3 9.5L10 14"
      stroke={color}
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
