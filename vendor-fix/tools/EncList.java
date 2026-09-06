import android.media.MediaCodecInfo;
import android.media.MediaCodecList;

public class EncList {
    public static void main(String[] a) {
        MediaCodecList l = new MediaCodecList(MediaCodecList.ALL_CODECS);
        for (MediaCodecInfo i : l.getCodecInfos()) {
            if (!i.isEncoder()) continue;
            for (String t : i.getSupportedTypes()) {
                if (!t.startsWith("video/")) continue;
                StringBuilder sb = new StringBuilder();
                sb.append(i.getName()).append("  ").append(t);
                try {
                    MediaCodecInfo.VideoCapabilities v =
                        i.getCapabilitiesForType(t).getVideoCapabilities();
                    sb.append("  W=").append(v.getSupportedWidths())
                      .append(" H=").append(v.getSupportedHeights())
                      .append(" bitrate=").append(v.getBitrateRange());
                } catch (Throwable t2) {
                    sb.append("  <caps error: ").append(t2.getClass().getSimpleName()).append(">");
                }
                System.out.println(sb);
            }
        }
        Runtime.getRuntime().halt(0);
    }
}
