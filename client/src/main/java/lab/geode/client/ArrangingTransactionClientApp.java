package lab.geode.client;

import lab.geode.client.model.ArrangingTransaction;
import lab.geode.client.model.BookingState;
import lab.geode.client.model.SimpleDate;
import lab.geode.client.model.SimpleTime;

import org.apache.geode.cache.Region;
import org.apache.geode.cache.client.ClientCache;
import org.apache.geode.cache.client.ClientCacheFactory;
import org.apache.geode.cache.client.ClientRegionShortcut;

import java.util.HashMap;

public final class ArrangingTransactionClientApp {

    private static final String LOCATOR_HOST = "192.168.0.150";
    private static final int    LOCATOR_PORT = 10334;
    private static final String REGION_NAME  = "ArrangingTransaction";

    public static void main(String[] args) throws Exception {
        String key = args.length > 0 ? args[0] : "TXN-PDX-001";

        ClientCache cache = new ClientCacheFactory()
                .addPoolLocator(LOCATOR_HOST, LOCATOR_PORT)
                .set("log-level", "warn")
                .create();

        try {
            Region<String, ArrangingTransaction> region =
                    cache.<String, ArrangingTransaction>createClientRegionFactory(
                            ClientRegionShortcut.CACHING_PROXY)
                         .create(REGION_NAME);

            ArrangingTransaction txn = buildSample(key);
            region.put(txn.getTransactionId(), txn);

            System.out.println("PUT  key=" + txn.getTransactionId());
            System.out.println("     " + txn);

            ArrangingTransaction fetched = region.get(key);
            System.out.println("GET  key=" + key);
            System.out.println("     " + fetched);
        } finally {
            cache.close();
        }
    }

    private static ArrangingTransaction buildSample(String transactionId) {
        HashMap<String, BookingState> stateMap = new HashMap<>();
        stateMap.put("BOOK-001", new BookingState("CONFIRMED", "PRIMARY"));
        stateMap.put("BOOK-002", new BookingState("PENDING",   "SECONDARY"));

        return new ArrangingTransaction()
                .setTransactionId(transactionId)
                .setBatchId("BATCH-001")
                .setDirection("BUY")
                .setCusip("037833100")
                .setMarket("NYSE")
                .setQuantity(5000L)
                .setStatus("PENDING")
                .setBookingStateMap(stateMap)
                .setCreatedAt(new SimpleTime(10, 30, 0))
                .setCreateOn(new SimpleDate(2026, 5, 6));
    }
}
