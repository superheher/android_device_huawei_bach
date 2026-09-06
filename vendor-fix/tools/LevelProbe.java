import android.media.MediaCodecInfo;
import android.media.MediaCodecList;

public class LevelProbe {
    public static void main(String[] a) {
        MediaCodecList l = new MediaCodecList(MediaCodecList.ALL_CODECS);
        for (MediaCodecInfo i : l.getCodecInfos()) {
            if (i.isEncoder()) continue;
            String n = i.getName();
            if (!n.startsWith("OMX.qcom.video.decoder.")) continue;
            for (String t : i.getSupportedTypes()) {
                MediaCodecInfo.CodecProfileLevel[] pl = i.getCapabilitiesForType(t).profileLevels;
                int maxLevel = 0, maxProfile = 0;
                for (MediaCodecInfo.CodecProfileLevel p : pl) {
                    if (p.level > maxLevel) maxLevel = p.level;
                    if (p.profile > maxProfile) maxProfile = p.profile;
                }
                System.out.printf("%-34s %-24s profiles/levels=%d  maxProfile=0x%x  maxLevel=0x%x%n",
                        n, t, pl.length, maxProfile, maxLevel);
                for (MediaCodecInfo.CodecProfileLevel p : pl)
                    System.out.printf("      profile=0x%-6x level=0x%x%n", p.profile, p.level);
            }
        }
        Runtime.getRuntime().halt(0);
    }
}
