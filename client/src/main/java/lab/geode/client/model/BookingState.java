package lab.geode.client.model;

import org.apache.geode.pdx.PdxReader;
import org.apache.geode.pdx.PdxSerializable;
import org.apache.geode.pdx.PdxWriter;

public class BookingState implements PdxSerializable {

    private String state;
    private String bookingType;

    public BookingState() {}

    public BookingState(String state, String bookingType) {
        this.state       = state;
        this.bookingType = bookingType;
    }

    @Override
    public void toData(PdxWriter writer) {
        writer.writeString("state", state)
              .writeString("bookingType", bookingType);
    }

    @Override
    public void fromData(PdxReader reader) {
        state       = reader.readString("state");
        bookingType = reader.readString("bookingType");
    }

    public String getState()       { return state; }
    public String getBookingType() { return bookingType; }

    @Override
    public String toString() {
        return "BookingState{state='" + state + "', bookingType='" + bookingType + "'}";
    }
}
