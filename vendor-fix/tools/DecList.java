import android.media.MediaCodecInfo;
import android.media.MediaCodecList;

public class DecList {
    public static void main(String[] a) {
        MediaCodecList l = new MediaCodecList(MediaCodecList.ALL_CODECS);
        for (MediaCodecInfo i : l.getCodecInfos()) {
            if (i.isEncoder()) continue;
            for (String t : i.getSupportedTypes()) {
                if (!t.startsWith("video/")) continue;
                StringBuilder sb = new StringBuilder();
                sb.append(String.format("%-38s %-26s", i.getName(), t));
                try {
                    MediaCodecInfo.VideoCapabilities v = i.getCapabilitiesForType(t).getVideoCapabilities();
                    sb.append(" W=").append(v.getSupportedWidths()).append(" H=").append(v.getSupportedHeights());
                    sb.append(v.areSizeAndRateSupported(1920,1080,60) ? "  1080p60=YES" : "  1080p60=no");
                    sb.append(v.areSizeAndRateSupported(1920,1080,30) ? "  1080p30=YES" : "  1080p30=no");
                } catch (Throwable e) { sb.append("  <caps error>"); }
                System.out.println(sb);
            }
        }
        Runtime.getRuntime().halt(0);
    }
}
