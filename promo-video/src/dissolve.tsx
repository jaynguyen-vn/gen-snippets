import React from "react";
import type { TransitionPresentation, TransitionPresentationComponentProps } from "@remotion/transitions";
import { AbsoluteFill, interpolate } from "remotion";

type DissolveProps = Record<string, never>;

// The scenes are transparent over a shared backdrop, so a plain fade leaves the
// outgoing scene fully visible under the incoming one. Here the outgoing scene
// clears out before the incoming one is fully in, with a slight depth push.
const DissolvePresentation: React.FC<TransitionPresentationComponentProps<DissolveProps>> = ({
  children,
  presentationDirection,
  presentationProgress,
}) => {
  const entering = presentationDirection === "entering";
  return (
    <AbsoluteFill
      style={{
        opacity: entering
          ? interpolate(presentationProgress, [0.35, 1], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })
          : interpolate(presentationProgress, [0, 0.55], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        scale: entering
          ? interpolate(presentationProgress, [0, 1], [1.03, 1])
          : interpolate(presentationProgress, [0, 1], [1, 0.97]),
      }}
    >
      {children}
    </AbsoluteFill>
  );
};

export const dissolve = (): TransitionPresentation<DissolveProps> => ({
  component: DissolvePresentation,
  props: {},
});
