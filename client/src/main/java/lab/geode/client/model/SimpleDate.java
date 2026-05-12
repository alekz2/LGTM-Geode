package lab.geode.client.model;

import org.apache.geode.pdx.PdxReader;
import org.apache.geode.pdx.PdxSerializable;
import org.apache.geode.pdx.PdxWriter;

public class SimpleDate implements PdxSerializable {

    private int year;
    private int month;
    private int day;

    public SimpleDate() {}

    public SimpleDate(int year, int month, int day) {
        this.year = year;
        this.month = month;
        this.day = day;
    }

    @Override
    public void toData(PdxWriter writer) {
        writer.writeInt("year", year)
              .writeInt("month", month)
              .writeInt("day", day);
    }

    @Override
    public void fromData(PdxReader reader) {
        year  = reader.readInt("year");
        month = reader.readInt("month");
        day   = reader.readInt("day");
    }

    public int getYear()  { return year; }
    public int getMonth() { return month; }
    public int getDay()   { return day; }

    @Override
    public String toString() {
        return String.format("%04d-%02d-%02d", year, month, day);
    }
}
