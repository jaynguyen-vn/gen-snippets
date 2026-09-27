import React from "react";
import { Audio } from "@remotion/media";
import { interpolate, Sequence, staticFile, useVideoConfig } from "remotion";

// Music: "Other World" by Lily J, Mixkit Stock Music Free License (https://mixkit.co/license/#musicFree).
// Sound effects: Mixkit Sound Effects Free License (https://mixkit.co/license/#sfxFree), items
// 2533 and 2534 (keys), 2542 (hard key), 3005, 2356 and 2358 (pops), 1490 (whoosh), 2350
// (sparkle). Trimmed to the hit and peak-normalised to -3 dBFS in public/sfx.

export type SfxName =
  | "key-1"
  | "key-2"
  | "key-3"
  | "key-4"
  | "key-hard"
  | "pop-expand"
  | "pop-panel"
  | "pop-word"
  | "whoosh"
  | "sparkle";

export const Sfx: React.FC<{ at: number; name: SfxName; volume?: number }> = ({ at, name, volume = 1 }) => (
  <Sequence from={at} name={`SFX ${name}`} layout="none">
    <Audio src={staticFile(`sfx/${name}.wav`)} volume={volume} />
  </Sequence>
);

const KEY_SAMPLES: SfxName[] = ["key-1", "key-3", "key-2", "key-4"];
const KEY_ACCENTS = [1, 0.82, 0.93, 0.78];

/** One click per typed character, rotating samples so fast typing does not sound mechanical. */
export const KeyTaps: React.FC<{ start: number; count: number; perChar: number; volume?: number }> = ({
  start,
  count,
  perChar,
  volume = 0.6,
}) => (
  <>
    {Array.from({ length: count }, (_, i) => (
      <Sfx
        key={i}
        at={start + i * perChar}
        name={KEY_SAMPLES[i % KEY_SAMPLES.length]}
        volume={volume * KEY_ACCENTS[i % KEY_ACCENTS.length]}
      />
    ))}
  </>
);

/**
 * The whoosh peaks ~14 frames after it starts, so starting it 21 frames before
 * the scene ends lands the peak in the middle of the 14-frame dissolve.
 */
export const ExitWhoosh: React.FC = () => {
  const { durationInFrames } = useVideoConfig();
  return <Sfx at={durationInFrames - 21} name="whoosh" volume={0.4} />;
};

// "Other World" by Lily J goes quiet, then its beat drops at 9.18 s. Skipping
// 43 frames (1.43 s) lands the drop on frame 232, the moment the signature
// expands; 0.62 brings the full mix to about -16 LUFS.
export const Soundtrack: React.FC = () => {
  const { durationInFrames } = useVideoConfig();
  return (
    <Audio
      src={staticFile("music/other-world.mp3")}
      trimBefore={43}
      volume={(f) =>
        interpolate(f, [0, 12, durationInFrames - 45, durationInFrames], [0, 0.62, 0.62, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        })
      }
    />
  );
};
