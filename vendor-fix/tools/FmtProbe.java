import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;

public class FmtProbe {
    public static void main(String[] a) {
        try {
            MediaExtractor ex = new MediaExtractor();
            ex.setDataSource(a[0]);
            System.out.println("tracks=" + ex.getTrackCount());
            for (int i = 0; i < ex.getTrackCount(); i++) {
                MediaFormat f = ex.getTrackFormat(i);
                System.out.println("  track " + i + ": " + f);
            }
            int t = -1; MediaFormat fmt = null;
            for (int i = 0; i < ex.getTrackCount(); i++) {
                MediaFormat f = ex.getTrackFormat(i);
                if (f.getString(MediaFormat.KEY_MIME).startsWith("video/")) { t = i; fmt = f; break; }
            }
            if (t < 0) { System.out.println("НЕТ ВИДЕОДОРОЖКИ"); Runtime.getRuntime().halt(0); }
            ex.selectTrack(t);
            String name = a.length > 1 ? a[1] : null;
            MediaCodec c = (name != null) ? MediaCodec.createByCodecName(name)
                                          : MediaCodec.createDecoderByType(fmt.getString(MediaFormat.KEY_MIME));
            System.out.println("создан: " + c.getName());
            try { c.configure(fmt, null, null, 0); System.out.println("configure: OK"); }
            catch (Throwable e) { System.out.println("configure: FAIL " + e); Runtime.getRuntime().halt(0); }
            try { c.start(); System.out.println("start: OK"); }
            catch (Throwable e) { System.out.println("start: FAIL " + e); Runtime.getRuntime().halt(0); }
            System.out.println("готов к декодированию");
        } catch (Throwable t) { System.out.println("ОШИБКА: " + t); }
        Runtime.getRuntime().halt(0);
    }
}
