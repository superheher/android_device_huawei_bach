import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;

public class DecProbe {
    static final String[] NAMES = {
        "OMX.qcom.video.decoder.avc","OMX.qcom.video.decoder.hevc","OMX.qcom.video.decoder.vp8",
        "OMX.qti.video.decoder.h263sw","OMX.qti.video.decoder.mpeg4sw",
        "OMX.qcom.video.decoder.vp9","OMX.qcom.video.decoder.divx","OMX.qti.video.decoder.divxsw",
        "OMX.qcom.video.decoder.divx311","OMX.qcom.video.decoder.divx4","OMX.qti.video.decoder.divx4sw",
        "OMX.qcom.video.decoder.mpeg4","OMX.qcom.video.decoder.mpeg2","OMX.qcom.video.decoder.h263",
        "OMX.qcom.video.decoder.wmv","OMX.qcom.video.decoder.vc1"
    };
    public static void main(String[] a) {
        MediaCodecList l = new MediaCodecList(MediaCodecList.ALL_CODECS);
        java.util.HashSet<String> listed = new java.util.HashSet<>();
        for (MediaCodecInfo i : l.getCodecInfos()) listed.add(i.getName());
        for (String n : NAMES) {
            boolean inList = listed.contains(n);
            String created;
            MediaCodec c = null;
            try { c = MediaCodec.createByCodecName(n); created = "OK"; }
            catch (Throwable t) { created = t.getClass().getSimpleName(); }
            finally { try { if (c != null) c.release(); } catch (Throwable ignored) {} }
            System.out.printf("%-38s listed=%-5s create=%s%n", n, inList, created);
        }
        Runtime.getRuntime().halt(0);
    }
}
