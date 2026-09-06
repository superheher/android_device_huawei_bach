import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.media.MediaFormat;
import java.nio.ByteBuffer;

public class EncBench {
    public static void main(String[] a) {
        String name = a[0], mime = a[1];
        int w = Integer.parseInt(a[2]), h = Integer.parseInt(a[3]);
        int br = Integer.parseInt(a[4]), fps = Integer.parseInt(a[5]);
        int want = a.length > 6 ? Integer.parseInt(a[6]) : 300;
        try { run(name, mime, w, h, br, fps, want); }
        catch (Throwable t) { System.out.println("RESULT=ERROR " + t.getClass().getSimpleName() + ": " + t.getMessage()); }
        Runtime.getRuntime().halt(0);
    }

    static int pickColor(String name, String mime) {
        MediaCodecList l = new MediaCodecList(MediaCodecList.ALL_CODECS);
        for (MediaCodecInfo i : l.getCodecInfos()) {
            if (!i.getName().equals(name)) continue;
            int[] cf = i.getCapabilitiesForType(mime).colorFormats;
            for (int c : cf) if (c == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar) return c;
            for (int c : cf) if (c == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar) return c;
            if (cf.length > 0) return cf[0];
        }
        return MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar;
    }

    static void run(String name, String mime, int w, int h, int br, int fps, int want) throws Exception {
        int color = pickColor(name, mime);
        MediaCodec c = MediaCodec.createByCodecName(name);
        MediaFormat f = MediaFormat.createVideoFormat(mime, w, h);
        f.setInteger(MediaFormat.KEY_COLOR_FORMAT, color);
        f.setInteger(MediaFormat.KEY_BIT_RATE, br);
        f.setInteger(MediaFormat.KEY_FRAME_RATE, fps);
        f.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);
        c.configure(f, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        c.start();

        int frameSize = w * h * 3 / 2;
        byte[] src = new byte[frameSize];
        for (int i = 0; i < frameSize; i++) src[i] = (byte) (i * 7 + 16);

        MediaCodec.BufferInfo bi = new MediaCodec.BufferInfo();
        int fed = 0, got = 0;
        long t0 = System.nanoTime();
        long deadline = t0 + 20L * 1000 * 1000 * 1000;
        while (got < want && System.nanoTime() < deadline) {
            if (fed < want) {
                int in = c.dequeueInputBuffer(2000);
                if (in >= 0) {
                    ByteBuffer b = c.getInputBuffer(in);
                    b.clear(); b.put(src, 0, Math.min(frameSize, b.capacity()));
                    long pts = (long) fed * 1000000L / fps;
                    c.queueInputBuffer(in, 0, Math.min(frameSize, b.capacity()), pts, 0);
                    fed++;
                }
            }
            int out = c.dequeueOutputBuffer(bi, 2000);
            if (out >= 0) {
                if ((bi.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) got++;
                c.releaseOutputBuffer(out, false);
            }
        }
        long dt = System.nanoTime() - t0;
        double sec = dt / 1e9;
        System.out.printf("RESULT=%s %dx%d @%d %dfps  color=0x%x  encoded=%d/%d  wall=%.2fs  achieved=%.1f fps%n",
                (got >= want ? "OK" : "SHORT"), w, h, br, fps, color, got, want, sec, got / sec);
        try { c.stop(); } catch (Throwable ignored) {}
        c.release();
    }
}
