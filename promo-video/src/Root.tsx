import { Composition, Folder } from "remotion";
import {
  EverywherePreview,
  ExpandPreview,
  FillInPreview,
  HookPreview,
  IntroPreview,
  OutroPreview,
  Promo,
  QuickSearchPreview,
  RichContentPreview,
} from "./Promo";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="GenSnippetsPromo"
        component={Promo}
        durationInFrames={1130}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="GenSnippetsPromoVertical"
        component={Promo}
        durationInFrames={1130}
        fps={30}
        width={1080}
        height={1920}
      />
      <Folder name="Scenes">
        <Composition id="Intro" component={IntroPreview} durationInFrames={88} fps={30} width={1920} height={1080} />
        <Composition id="Hook" component={HookPreview} durationInFrames={110} fps={30} width={1920} height={1080} />
        <Composition id="Expand" component={ExpandPreview} durationInFrames={160} fps={30} width={1920} height={1080} />
        <Composition
          id="Everywhere"
          component={EverywherePreview}
          durationInFrames={178}
          fps={30}
          width={1920}
          height={1080}
        />
        <Composition
          id="RichContent"
          component={RichContentPreview}
          durationInFrames={170}
          fps={30}
          width={1920}
          height={1080}
        />
        <Composition id="FillIn" component={FillInPreview} durationInFrames={200} fps={30} width={1920} height={1080} />
        <Composition
          id="QuickSearch"
          component={QuickSearchPreview}
          durationInFrames={180}
          fps={30}
          width={1920}
          height={1080}
        />
        <Composition id="Outro" component={OutroPreview} durationInFrames={143} fps={30} width={1920} height={1080} />
      </Folder>
    </>
  );
};
