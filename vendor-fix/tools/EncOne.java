import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.media.MediaFormat;
import android.view.Surface;

public class EncOne {
    public static void main(String[] args) {
        String name = args[0], mime = args[1];
        int w = Integer.parseInt(args[2]), h = Integer.parseInt(args[3]);
        int br = args.length > 4 ? Integer.parseInt(args[4]) : 4000000;
        int fps = args.length > 5 ? Integer.parseInt(args[5]) : 30;
        // is it even in the framework's list?
        boolean listed = false;
        MediaCodecList l = new MediaCodecList(MediaCodecList.ALL_CODECS);
        for (MediaCodecInfo i : l.getCodecInfos()) {
            if (i.getName().equals(name)) { listed = true; break; }
        }
        System.out.println("listed_in_MediaCodecList=" + listed);
        MediaCodec c = null; Surface surf = null;
        try {
            c = MediaCodec.createByCodecName(name);
            System.out.println("created=OK");
            MediaFormat f = MediaFormat.createVideoFormat(mime, w, h);
            f.setInteger(MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface);
            f.setInteger(MediaFormat.KEY_BIT_RATE, br);
            f.setInteger(MediaFormat.KEY_FRAME_RATE, fps);
            f.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);
            c.configure(f, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
            surf = c.createInputSurface();
            c.start();
            System.out.println("RESULT=OK " + name + " " + w + "x" + h + " @" + br + " " + fps + "fps");
        } catch (Throwable t) {
            System.out.println("RESULT=FAIL " + name + " " + w + "x" + h + " @" + br + " " + fps + "fps "
                    + t.getClass().getSimpleName() + ": " + String.valueOf(t.getMessage()).replace('\n',' '));
        } finally {
            try { if (c != null) c.stop(); } catch (Throwable ignored) {}
            try { if (c != null) c.release(); } catch (Throwable ignored) {}
            try { if (surf != null) surf.release(); } catch (Throwable ignored) {}
        }
        Runtime.getRuntime().halt(0);
    }
}
