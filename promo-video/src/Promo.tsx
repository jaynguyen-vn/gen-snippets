import React from "react";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { AbsoluteFill } from "remotion";
import { Soundtrack } from "./audio";
import { Background } from "./components/Background";
import { dissolve } from "./dissolve";
import { EverywhereScene } from "./scenes/EverywhereScene";
import { ExpandScene } from "./scenes/ExpandScene";
import { FillInScene } from "./scenes/FillInScene";
import { HookScene } from "./scenes/HookScene";
import { IntroScene } from "./scenes/IntroScene";
import { OutroScene } from "./scenes/OutroScene";
import { QuickSearchScene } from "./scenes/QuickSearchScene";
import { RichContentScene } from "./scenes/RichContentScene";

// Scenes are transparent; the backdrop sits underneath so crossfades never flash.
export const Promo: React.FC = () => (
  <AbsoluteFill>
    <Background />
    <Soundtrack />
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={88} name="Intro">
        <IntroScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={dissolve()} timing={linearTiming({ durationInFrames: 14 })} />
      <TransitionSeries.Sequence durationInFrames={110} name="Hook">
        <HookScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={dissolve()} timing={linearTiming({ durationInFrames: 14 })} />
      <TransitionSeries.Sequence durationInFrames={160} name="Expand">
        <ExpandScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={dissolve()} timing={linearTiming({ durationInFrames: 14 })} />
      <TransitionSeries.Sequence durationInFrames={178} name="Everywhere">
        <EverywhereScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={dissolve()} timing={linearTiming({ durationInFrames: 14 })} />
      <TransitionSeries.Sequence durationInFrames={170} name="Images & files">
        <RichContentScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={dissolve()} timing={linearTiming({ durationInFrames: 14 })} />
      <TransitionSeries.Sequence durationInFrames={200} name="Fill-in">
        <FillInScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={dissolve()} timing={linearTiming({ durationInFrames: 14 })} />
      <TransitionSeries.Sequence durationInFrames={180} name="Quick Search">
        <QuickSearchScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={dissolve()} timing={linearTiming({ durationInFrames: 15 })} />
      <TransitionSeries.Sequence durationInFrames={143} name="Outro">
        <OutroScene />
      </TransitionSeries.Sequence>
    </TransitionSeries>
  </AbsoluteFill>
);

const withBackground = (Scene: React.FC) => {
  const Preview: React.FC = () => (
    <AbsoluteFill>
      <Background />
      <Scene />
    </AbsoluteFill>
  );
  return Preview;
};

export const IntroPreview = withBackground(IntroScene);
export const HookPreview = withBackground(HookScene);
export const ExpandPreview = withBackground(ExpandScene);
export const EverywherePreview = withBackground(EverywhereScene);
export const RichContentPreview = withBackground(RichContentScene);
export const FillInPreview = withBackground(FillInScene);
export const QuickSearchPreview = withBackground(QuickSearchScene);
export const OutroPreview = withBackground(OutroScene);
