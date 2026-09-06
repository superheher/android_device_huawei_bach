import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import java.nio.ByteBuffer;

public class DecBench {
    public static void main(String[] a) {
        String path = a[0], name = a.length > 1 ? a[1] : null;
        try { run(path, name); }
        catch (Throwable t) { System.out.println("RESULT=ERROR " + t.getClass().getSimpleName() + ": " + t.getMessage()); for (StackTraceElement e : t.getStackTrace()) System.out.println("    at " + e); }
        Runtime.getRuntime().halt(0);
    }

    static void run(String path, String name) throws Exception {
        MediaExtractor ex = new MediaExtractor();
        ex.setDataSource(path);
        int track = -1; MediaFormat fmt = null;
        for (int i = 0; i < ex.getTrackCount(); i++) {
            MediaFormat f = ex.getTrackFormat(i);
            if (f.getString(MediaFormat.KEY_MIME).startsWith("video/")) { track = i; fmt = f; break; }
        }
        ex.selectTrack(track);
        int w = fmt.getInteger(MediaFormat.KEY_WIDTH), h = fmt.getInteger(MediaFormat.KEY_HEIGHT);
        MediaCodec c = (name != null) ? MediaCodec.createByCodecName(name)
                                      : MediaCodec.createDecoderByType(fmt.getString(MediaFormat.KEY_MIME));
        c.configure(fmt, null, null, 0);
        c.start();
        MediaCodec.BufferInfo bi = new MediaCodec.BufferInfo();
        boolean eos = false; int got = 0;
        long t0 = System.nanoTime();
        long deadline = t0 + 30L * 1000 * 1000 * 1000;
        while (System.nanoTime() < deadline) {
            if (!eos) {
                int in = c.dequeueInputBuffer(2000);
                if (in >= 0) {
                    ByteBuffer b = c.getInputBuffer(in);
                    int sz = ex.readSampleData(b, 0);
                    if (sz < 0) { c.queueInputBuffer(in, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM); eos = true; }
                    else { c.queueInputBuffer(in, 0, sz, ex.getSampleTime(), 0); ex.advance(); }
                }
            }
            int out = c.dequeueOutputBuffer(bi, 2000);
            if (out >= 0) {
                if ((bi.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0 && bi.size > 0) got++;
                c.releaseOutputBuffer(out, false);
                if ((bi.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) break;
            }
        }
        double sec = (System.nanoTime() - t0) / 1e9;
        System.out.printf("RESULT %s %dx%d  frames=%d  wall=%.2fs  achieved=%.1f fps  blocks/s=%.0f%n",
                c.getName(), w, h, got, sec, got / sec, (got / sec) * ((w + 15) / 16) * ((h + 15) / 16));
        try { c.stop(); } catch (Throwable ignored) {}
        c.release(); ex.release();
    }
}
