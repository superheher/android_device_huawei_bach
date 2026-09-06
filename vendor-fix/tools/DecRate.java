import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import java.nio.ByteBuffer;

public class DecRate {
    public static void main(String[] a) {
        try { run(a[0], a[1], Integer.parseInt(a[2]), a.length > 3 ? Integer.parseInt(a[3]) : -1); }
        catch (Throwable t) { System.out.println("ERROR " + t); }
        Runtime.getRuntime().halt(0);
    }
    static void run(String path, String name, int rate, int prio) throws Exception {
        MediaExtractor ex = new MediaExtractor(); ex.setDataSource(path);
        int tr=-1; MediaFormat f=null;
        for (int i=0;i<ex.getTrackCount();i++){MediaFormat g=ex.getTrackFormat(i);
            if(g.getString(MediaFormat.KEY_MIME).startsWith("video/")){tr=i;f=g;break;}}
        ex.selectTrack(tr);
        if (rate > 0) f.setInteger(MediaFormat.KEY_OPERATING_RATE, rate);
        if (prio >= 0) f.setInteger(MediaFormat.KEY_PRIORITY, prio);
        MediaCodec c = MediaCodec.createByCodecName(name);
        c.configure(f, null, null, 0); c.start();
        MediaCodec.BufferInfo bi = new MediaCodec.BufferInfo();
        boolean eos=false; int got=0; long t0=System.nanoTime();
        long dl=t0+25L*1000*1000*1000;
        while (got < 600 && System.nanoTime() < dl) {
            if (!eos) { int in=c.dequeueInputBuffer(2000);
                if (in>=0){ByteBuffer b=c.getInputBuffer(in); int sz=ex.readSampleData(b,0);
                    if(sz<0){c.queueInputBuffer(in,0,0,0,MediaCodec.BUFFER_FLAG_END_OF_STREAM);eos=true;}
                    else{c.queueInputBuffer(in,0,sz,ex.getSampleTime(),0);ex.advance();}}}
            int out=c.dequeueOutputBuffer(bi,2000);
            if(out>=0){ if((bi.flags&MediaCodec.BUFFER_FLAG_CODEC_CONFIG)==0&&bi.size>0) got++;
                c.releaseOutputBuffer(out,false);
                if((bi.flags&MediaCodec.BUFFER_FLAG_END_OF_STREAM)!=0) break; }
        }
        double sec=(System.nanoTime()-t0)/1e9;
        System.out.printf("rate=%-5s prio=%-3s frames=%d  %.1f fps%n",
            rate>0?String.valueOf(rate):"none", prio>=0?String.valueOf(prio):"none", got, got/sec);
        try{c.stop();}catch(Throwable ig){} c.release(); ex.release();
    }
}
