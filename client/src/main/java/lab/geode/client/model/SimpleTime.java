package lab.geode.client.model;

import org.apache.geode.pdx.PdxReader;
import org.apache.geode.pdx.PdxSerializable;
import org.apache.geode.pdx.PdxWriter;

public class SimpleTime implements PdxSerializable {

    private int hour;
    private int minute;
    private int second;

    public SimpleTime() {}

    public SimpleTime(int hour, int minute, int second) {
        this.hour   = hour;
        this.minute = minute;
        this.second = second;
    }

    @Override
    public void toData(PdxWriter writer) {
        writer.writeInt("hour", hour)
              .writeInt("minute", minute)
              .writeInt("second", second);
    }

    @Override
    public void fromData(PdxReader reader) {
        hour   = reader.readInt("hour");
        minute = reader.readInt("minute");
        second = reader.readInt("second");
    }

    public int getHour()   { return hour; }
    public int getMinute() { return minute; }
    public int getSecond() { return second; }

    @Override
    public String toString() {
        return String.format("%02d:%02d:%02d", hour, minute, second);
    }
}
