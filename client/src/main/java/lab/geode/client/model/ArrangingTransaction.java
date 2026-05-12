package lab.geode.client.model;

import org.apache.geode.pdx.PdxReader;
import org.apache.geode.pdx.PdxSerializable;
import org.apache.geode.pdx.PdxWriter;

import java.util.HashMap;

public class ArrangingTransaction implements PdxSerializable {

    private Long quantity;
    private String batchId;
    private String transactionId;
    private String direction;
    private String cusip;
    private String market;
    private String status;
    private HashMap<String, BookingState> bookingStateMap;
    private SimpleTime createdAt;
    private SimpleDate createOn;

    public ArrangingTransaction() {}

    @Override
    public void toData(PdxWriter writer) {
        writer.writeLong("quantity",        quantity == null ? 0L : quantity)
              .writeString("batchId",       batchId)
              .writeString("transactionId", transactionId)
              .writeString("direction",     direction)
              .writeString("cusip",         cusip)
              .writeString("market",        market)
              .writeString("status",        status)
              .writeObject("bookingStateMap", bookingStateMap)
              .writeObject("createdAt",     createdAt)
              .writeObject("createOn",      createOn);
    }

    @Override
    @SuppressWarnings("unchecked")
    public void fromData(PdxReader reader) {
        quantity        = reader.readLong("quantity");
        batchId         = reader.readString("batchId");
        transactionId   = reader.readString("transactionId");
        direction       = reader.readString("direction");
        cusip           = reader.readString("cusip");
        market          = reader.readString("market");
        status          = reader.readString("status");
        bookingStateMap = (HashMap<String, BookingState>) reader.readObject("bookingStateMap");
        createdAt       = (SimpleTime) reader.readObject("createdAt");
        createOn        = (SimpleDate) reader.readObject("createOn");
    }

    public Long getQuantity()                              { return quantity; }
    public String getBatchId()                             { return batchId; }
    public String getTransactionId()                       { return transactionId; }
    public String getDirection()                           { return direction; }
    public String getCusip()                               { return cusip; }
    public String getMarket()                              { return market; }
    public String getStatus()                              { return status; }
    public HashMap<String, BookingState> getBookingStateMap() { return bookingStateMap; }
    public SimpleTime getCreatedAt()                       { return createdAt; }
    public SimpleDate getCreateOn()                        { return createOn; }

    public ArrangingTransaction setQuantity(Long quantity)            { this.quantity = quantity; return this; }
    public ArrangingTransaction setBatchId(String batchId)            { this.batchId = batchId; return this; }
    public ArrangingTransaction setTransactionId(String transactionId){ this.transactionId = transactionId; return this; }
    public ArrangingTransaction setDirection(String direction)        { this.direction = direction; return this; }
    public ArrangingTransaction setCusip(String cusip)                { this.cusip = cusip; return this; }
    public ArrangingTransaction setMarket(String market)              { this.market = market; return this; }
    public ArrangingTransaction setStatus(String status)              { this.status = status; return this; }
    public ArrangingTransaction setBookingStateMap(HashMap<String, BookingState> bookingStateMap) {
        this.bookingStateMap = bookingStateMap; return this;
    }
    public ArrangingTransaction setCreatedAt(SimpleTime createdAt)    { this.createdAt = createdAt; return this; }
    public ArrangingTransaction setCreateOn(SimpleDate createOn)      { this.createOn = createOn; return this; }

    @Override
    public String toString() {
        return "ArrangingTransaction{" +
               "transactionId='" + transactionId + '\'' +
               ", batchId='" + batchId + '\'' +
               ", cusip='" + cusip + '\'' +
               ", market='" + market + '\'' +
               ", direction='" + direction + '\'' +
               ", quantity=" + quantity +
               ", status='" + status + '\'' +
               ", bookingStateMap=" + bookingStateMap +
               ", createdAt=" + createdAt +
               ", createOn=" + createOn +
               '}';
    }
}
